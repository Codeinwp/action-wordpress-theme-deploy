#!/bin/bash

# Note that this does not use pipefail
# because if the grep later doesn't match any deleted files,
# which is likely the majority case,
# it does not exit with a 0, and I only care about the final exit.
set -eo

# Ensure SVN username and password are set
# IMPORTANT: while secrets are encrypted and not viewable in the GitHub UI,
# they are by necessity provided as plaintext in the context of the Action,
# so do not echo or use debug mode unless you want your secrets exposed!
if [[ -z "$SVN_USERNAME" ]]; then
	echo "Set the SVN_USERNAME secret"
	exit 1
fi

if [[ -z "$SVN_PASSWORD" ]]; then
	echo "Set the SVN_PASSWORD secret"
	exit 1
fi

# Allow some ENV variables to be customized
if [[ -z "$SLUG" ]]; then
	SLUG=${GITHUB_REPOSITORY#*/}
fi
echo "ℹ︎ SLUG is $SLUG"

# Does it even make sense for VERSION to be editable in a workflow definition?
if [[ -z "$VERSION" ]]; then
	VERSION="${GITHUB_REF#refs/tags/}"
	VERSION="${VERSION#v}"
fi
echo "ℹ︎ VERSION is $VERSION"

if [[ -z "$BUILD_DIR" ]] || [[ $BUILD_DIR == "./" ]]; then
	BUILD_DIR=false
elif [[ $BUILD_DIR == ./* ]]; then 
	BUILD_DIR=${BUILD_DIR:2}
fi

if [[ "$BUILD_DIR" != false ]]; then
	if [[ $BUILD_DIR != /* ]]; then 
		BUILD_DIR="${GITHUB_WORKSPACE%/}/${BUILD_DIR%/}"
	fi
	echo "ℹ︎ BUILD_DIR is $BUILD_DIR"
fi

# SVN_URL="https://themes.svn.wordpress.org/${SLUG}/" Test
SVN_URL="https://svn.riouxsvn.com/${SLUG}/"
SVN_DIR="${HOME}/svn-${SLUG}"

echo "➤ Checking out .org repository..."
svn checkout --depth immediates "$SVN_URL" "$SVN_DIR"
cd "$SVN_DIR"


if [[ "$BUILD_DIR" = false ]]; then
	echo "➤ Copying files..."
	if [[ -e "$GITHUB_WORKSPACE/.distignore" ]]; then
		echo "ℹ︎ Using .distignore"
		# The --delete flag will delete anything in destination that no longer exists in source
		rsync -rc --exclude-from="$GITHUB_WORKSPACE/.distignore" "$GITHUB_WORKSPACE/" "$VERSION/" --delete --delete-excluded
	else
		echo "ℹ︎ Using .gitattributes"

		cd "$GITHUB_WORKSPACE"

		# "Export" a cleaned copy to a temp directory
		TMP_DIR="${HOME}/archivetmp"
		mkdir "$TMP_DIR"

		git config --global user.email "10upbot+github@10up.com"
		git config --global user.name "10upbot on GitHub"

		# If there's no .gitattributes file, write a default one into place
		if [[ ! -e "$GITHUB_WORKSPACE/.gitattributes" ]]; then
			cat > "$GITHUB_WORKSPACE/.gitattributes" <<-EOL
			/$ASSETS_DIR export-ignore
			/.gitattributes export-ignore
			/.gitignore export-ignore
			/.github export-ignore
			EOL

			# Ensure we are in the $GITHUB_WORKSPACE directory, just in case
			# The .gitattributes file has to be committed to be used
			# Just don't push it to the origin repo :)
			git add .gitattributes && git commit -m "Add .gitattributes file"
		fi

		# This will exclude everything in the .gitattributes file with the export-ignore flag
		git archive HEAD | tar x --directory="$TMP_DIR"

		cd "$SVN_DIR"

		# Copy from clean copy to /trunk, excluding dotorg assets
		# The --delete flag will delete anything in destination that no longer exists in source
		rsync -rc "$TMP_DIR/" "$VERSION/" --delete --delete-excluded
	fi
else
	echo "ℹ︎ Copying files from build directory..."
	rsync -rc "$BUILD_DIR/" "$VERSION/" --delete --delete-excluded
fi

# Add everything and commit to SVN
# The force flag ensures we recurse into subdirectories even if they are already added
# Suppress stdout in favor of svn status later for readability
echo "➤ Preparing files..."
svn add . --force > /dev/null

# SVN delete all deleted files
# Also suppress stdout here
svn status | grep '^\!' | sed 's/! *//' | xargs -I% svn rm %@ > /dev/null

#Resolves => SVN commit failed: Directory out of date
svn update

svn status

echo "➤ Committing files..."
svn commit -m "Update to version $VERSION from GitHub" --no-auth-cache --non-interactive  --username "$SVN_USERNAME" --password "$SVN_PASSWORD"

echo "✓ Theme deployed!"
