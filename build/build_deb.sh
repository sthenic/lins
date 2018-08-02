# Organize artifacts
echo -n "Organizing artifacts..."
mkdir -p "deb/usr/share/lins"
cp "../lins" "deb/usr/share/lins/lins"

mkdir -p "deb/usr/share/doc/lins"
cp "../LICENSE" "deb/usr/share/doc/lins/copyright"
echo  >> "deb/usr/share/doc/lins/copyright"
cat "../THIRD_PARTY_LICENSES.md" >> "deb/usr/share/doc/lins/copyright"
echo " done."

# Update version information
LINS_VERSION=$(cat ../VERSION)
echo -n "Updating version information..."
sed -i "s/Version:.*$/Version: $LINS_VERSION/g" "deb/DEBIAN/control"
echo " done."

# Create .deb
dpkg-deb -b deb/ lins-$LINS_VERSION-$(uname -m).deb
