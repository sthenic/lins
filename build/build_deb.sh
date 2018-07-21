# Organize artifacts
echo -n "Organizing artifacts..."
mkdir -p "deb/usr/share"
cp "../lins" "deb/usr/share/lins"
echo " done."

# Update version information
LINS_VERSION=$(cat ../VERSION)
echo -n "Updating version information..."
sed -i "s/Version:.*$/Version: $LINS_VERSION/g" "deb/DEBIAN/control"
echo " done."

# Create .deb
dpkg-deb -b deb/ lins-$LINS_VERSION-$(uname -m).deb
