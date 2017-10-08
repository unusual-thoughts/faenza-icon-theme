mkdir -p build/

make_links () {
	dirname="$1"
	size="$2"
	target_iconname="$3"
	links="$4"
	suffix="$5"

	for link in $links; do
		link_dirname="$dirname"
		if [[ "$link" == *:* ]]; then
			link_dirname="$(echo "$link"|cut -d: -f1)"
			link="$(echo "$link"|cut -d: -f2)"
			mkdir -p "build/${link_dirname}/${size}/"
		fi
		link_target="$(realpath -m --relative-to "${link_dirname}/${size}/" "${dirname}/${size}/${target_iconname}${suffix}")"
		ln -sf "${link_target}" "build/${link_dirname}/${size}/${link}${suffix}"
	done
}

make_icon () {
	dirname="$1"
	iconname="$2"
	source="$3"
	size="$4"
	links="$5"

	svgfile="$dirname/$source/$iconname.svg"
	pngfile="build/$dirname/$size/$iconname.png"
	if [ ! -e "$svgfile" ]; then
		source='.'
	fi
	if [ ! -e "$svgfile" ]; then
		echo -e "    \e[31m$iconname \e[1mMISSING\e[22m\e[0m in $source (to build $size)"
	else
		if [ -L "$svgfile" ]; then
			svgtarget="$(realpath --relative-to "$PWD" "$svgfile")"
			target_category="$(echo "$svgtarget"| cut -d'/' -f1)"
			target_filename="$(basename "$svgtarget")"
			target="$(realpath -m --relative-to "/$dirname/$size/" "/$target_category/$size/${target_filename%%.svg}.png")"
			ln -sf "$target" "$pngfile"
		else
			if [ ! -e "$pngfile" ]; then
				inkscape -z -e "$pngfile" -w "$size" -h "$size" "$svgfile" > /dev/null
			fi
		fi
		make_links "$dirname" "$size" "$iconname" "$links" ".png"
	fi
}

make_svg () {
	dirname="$1"
	iconname="$2"
	links="$3"

	sourcesvg="$dirname/$iconname.svg"
	targetsvg="build/$dirname/scalable/$iconname.svg"
	if [ ! -e "$sourcesvg" ]; then
		echo -e "    \e[31m$iconname \e[1mMISSING\e[22m\e[0m in '.' to build svg"
	else
		# This is probably not the most simple version of the svg, should use one from packages instead?
		cp "$sourcesvg" "$targetsvg"
		make_links "$dirname" scalable "$iconname" "$links" ".svg"
	fi
}

for lstfile in *.lst; do
	dirname=${lstfile%%.lst}
	echo -e "\e[32m\e[1m[ $dirname ]\e[0m"
	mkdir -p build/$dirname/{16,22,24,32,48,64,96,scalable}
	cat $lstfile | grep -v '^$' | while read line; do
		arr=($line)
		iconname="${arr[0]}"
		links="${arr[@]:1}"
		echo -e "  - \e[33m$iconname\e[0m -> $links"
		if [[ "$iconname" == *:* ]]; then
			dirname="$(echo "$iconname"|cut -d: -f1)"
			iconname="$(echo "$iconname"|cut -d: -f2)"
			mkdir -p build/$dirname/{16,22,24,32,48,64,96,scalable}
		fi


		make_icon "$dirname" "$iconname" "extra small" 16 "$links" &
		make_icon "$dirname" "$iconname" "extra small" 22 "$links" &
		make_icon "$dirname" "$iconname" "extra small" 24 "$links" &
		make_icon "$dirname" "$iconname" "extra small" 32 "$links" &
		make_icon "$dirname" "$iconname" "small" 48 "$links" &
		make_icon "$dirname" "$iconname" "." 64 "$links" &
		make_icon "$dirname" "$iconname" "." 96 "$links"
		make_svg "$dirname" "$iconname" "$links"
	done
done
