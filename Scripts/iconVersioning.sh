#!/bin/sh
export PATH=/opt/local/bin/:/opt/local/sbin:$PATH:/usr/local/bin:

convertPath=`which convert`
gsPath=`which gs`

if [[ ! -f ${convertPath} || -z ${convertPath} ]]; then
convertValidation=true;
else
convertValidation=false;
fi

if [[ ! -f ${gsPath} || -z ${gsPath} ]]; then
gsValidation=true;
else
gsValidation=false;
fi

if [[ "$convertValidation" = true || "$gsValidation" = true ]]; then
echo "WARNING: Skipping Icon versioning, you need to install ImageMagick and ghostscript (fonts) first, you can use brew to simplify process:"

if [[ "$convertValidation" = true ]]; then
echo "brew install imagemagick"
fi
if [[ "$gsValidation" = true ]]; then
echo "brew install ghostscript"
fi
exit 0;
fi

PATH_TO_PLIST="$(find . -name Info.plist)"
echo  "$PATH_TO_PLIST"

version=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${SRCROOT}/${PATH_TO_PLIST}"`
build_num=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${SRCROOT}/${PATH_TO_PLIST}"`
# echo "version ${version}"
# echo "build_num ${build_num}"

# Check if we are under a Git or Hg repo
if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
commit=`git rev-parse --short HEAD`
branch=`git rev-parse --abbrev-ref HEAD`
else
commit=`hg identify -i`
branch=`hg identify -b`
fi;

#SRCROOT=..
#CONFIGURATION_BUILD_DIR=.
#UNLOCALIZED_RESOURCES_FOLDER_PATH=.

#commit="3783bab"
#branch="master"
#version="3.4"
#build_num="9999"

shopt -s extglob
build_num="${build_num##*( )}"
shopt -u extglob
caption="V(${version})_B($build_num)\n${branch}\n${commit}"

echo $caption

function abspath() { pushd . > /dev/null; if [ -d "$1" ]; then cd "$1"; dirs -l +0; else cd "`dirname \"$1\"`"; cur_dir=`dirs -l +0`; if [ "$cur_dir" == "/" ]; then echo "$cur_dir`basename \"$1\"`"; else echo "$cur_dir/`basename \"$1\"`"; fi; fi; popd > /dev/null; }

function processIcon() {
base_path=$1

echo base_path

#this is the change
target_path=$base_path


width=`identify -format %w ${base_path}`
height=`identify -format %h ${base_path}`

band_height=$((($height * 47) / 100))
band_position=$(($height - $band_height))
text_position=$(($band_position - 3))
point_size=$(((13 * $width) / 100))

echo "Image dimensions ($width x $height) - band height $band_height @ $band_position - point size $point_size"

#
# blur band and text
#
convert ${base_path} -blur 10x8 /tmp/blurred.png
convert /tmp/blurred.png -gamma 0 -fill white -draw "rectangle 0,$band_position,$width,$height" /tmp/mask.png
convert -size ${width}x${band_height} xc:none -fill 'rgba(0,0,0,0.2)' -draw "rectangle 0,0,$width,$band_height" /tmp/labels-base.png
convert -background none -size ${width}x${band_height} -pointsize $point_size -fill white -gravity center -gravity South caption:"$caption" /tmp/labels.png

convert ${base_path} /tmp/blurred.png /tmp/mask.png -composite /tmp/temp.png

rm /tmp/blurred.png
rm /tmp/mask.png

#
# compose final image
#
filename=New${base_file}
convert /tmp/temp.png /tmp/labels-base.png -geometry +0+$band_position -composite /tmp/labels.png -geometry +0+$text_position -geometry +${w}-${h} -composite "${target_path}"

# clean up
rm /tmp/temp.png
rm /tmp/labels-base.png
rm /tmp/labels.png

echo "Overlayed ${target_path}"
}

PATH_TO_APPICON="$(find . -name AppIcon.appiconset)"
echo  "$PATH_TO_APPICON"


if [ $CONFIGURATION = "Release" ]; then
cp  $SRCROOT/${PATH_TO_APPICON}/icons/*.png "${SRCROOT}/${PATH_TO_APPICON}/"
echo "Exit"
exit 0
fi


if [ -d "${SRCROOT}/${PATH_TO_APPICON}/icons/"]
then
#echo "Directory exists."
# get original icon to copy to assets
cp  "${SRCROOT}/${PATH_TO_APPICON}/icons"/*.png "${SRCROOT}/${PATH_TO_APPICON}/"
else
#echo "Directory NOT exists."
# copy orgin to AppIcon
rsync -rv  --include '*.png' --exclude '*' "${SRCROOT}/${PATH_TO_APPICON}/" "${SRCROOT}/${PATH_TO_APPICON}/icons/"
fi

for entry in "${SRCROOT}/${PATH_TO_APPICON}"/*.png
do
processIcon "$entry"
done


