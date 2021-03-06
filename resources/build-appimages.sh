#! /bin/bash

set -x
set -e

# use RAM disk if possible
if [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
else
    TEMP_BASE=/tmp
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" AppImageUpdate-build-XXXXXX)

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT=$(readlink -f $(dirname $(dirname $0)))
OLD_CWD=$(readlink -f .)

pushd "$BUILD_DIR"

cmake "$REPO_ROOT" \
    -DBUILD_FLTK_UI=ON \
    -DBUILD_QT_UI=ON \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo

# create AppDir
mkdir -p AppDir

# now, compile and install to AppDir
make -j$(nproc) install DESTDIR=AppDir

# install resources into AppDir
mkdir -p AppDir/usr/share/{applications,icons/hicolor/scalable/apps/} AppDir/resources
cp -v "$REPO_ROOT"/resources/*.desktop AppDir/usr/share/applications/
cp -v "$REPO_ROOT"/resources/*.svg AppDir/usr/share/icons/hicolor/scalable/apps/
cp -v "$REPO_ROOT"/resources/*.xpm AppDir/resources/

# determine Git commit ID
# linuxdeployqt uses this for naming the file
export VERSION=$(cd "$REPO_ROOT" && git rev-parse --short HEAD)

# prepend Travis build number if possible
if [ "$TRAVIS_BUILD_NUMBER" != "" ]; then
    export VERSION="$TRAVIS_BUILD_NUMBER-$VERSION"
fi

# get linuxdeployqt
wget https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage
chmod +x linuxdeployqt-continuous-x86_64.AppImage

# bundle applications
./linuxdeployqt-continuous-x86_64.AppImage \
    AppDir/usr/share/applications/appimageupdatetool.desktop \
    -verbose=1 -bundle-non-qt-libs \
    -executable=AppDir/usr/bin/AppImageUpdate \
    -executable=AppDir/usr/bin/objdump \
    -executable=AppDir/usr/bin/AppImageUpdate-Qt

# get appimagetool
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage

# remove unnecessary data
find AppDir -type f -iname '*.a' -delete
rm -rf AppDir/usr/include

if [ ! -x AppDir/usr/bin/appimageupdatetool ]; then
    echo "Error: appimageupdatetool binary not found!"
    exit 1
fi

# create appimageupdatetool AppImage
./appimagetool-x86_64.AppImage -v --exclude-file "$REPO_ROOT"/resources/appimageupdatetool.ignore AppDir \
    -u 'gh-releases-zsync|AppImage|AppImageUpdate|continuous|appimageupdatetool-*x86_64.AppImage.zsync'

if [ ! -x AppDir/usr/bin/AppImageUpdate ]; then
    echo "Error: AppImageUpdate binary not found!"
    exit 1
fi

# change AppDir root to fit the GUI
pushd AppDir
rm AppRun && ln -s usr/bin/AppImageUpdate AppRun
rm *.desktop && cp usr/share/applications/AppImageUpdate.desktop .
popd

# create AppImageUpdate AppImage
./appimagetool-x86_64.AppImage -v --exclude-file "$REPO_ROOT"/resources/AppImageUpdate.ignore AppDir \
    -u 'gh-releases-zsync|AppImage|AppImageUpdate|continuous|AppImageUpdate-*x86_64.AppImage.zsync'

if [ ! -x AppDir/usr/bin/AppImageUpdate-Qt ]; then
    echo "Error: AppImageUpdate-Qt binary not found!"
    exit 1
fi

# change AppDir root to fit the Qt UI
pushd AppDir
rm AppRun && ln -s usr/bin/AppImageUpdate-Qt AppRun
rm *.desktop && cp usr/share/applications/AppImageUpdate-Qt.desktop .
popd

# create AppImageUpdate AppImage
./appimagetool-x86_64.AppImage -v --exclude-file "$REPO_ROOT"/resources/AppImageUpdate-Qt.ignore AppDir \
    -u 'gh-releases-zsync|AppImage|AppImageUpdate|continuous|AppImageUpdate-Qt-*x86_64.AppImage.zsync'

# move AppImages to old cwd
mv {appimageupdatetool,AppImageUpdate}*.AppImage* "$OLD_CWD"/

popd
