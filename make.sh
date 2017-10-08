mkdir -p build/

make_links () {
    categpry="$1"
    dstdir="$2"
    size="$3"
    target_icon="$4"
    links="$5"
    suffix="$6"

    for link in $links; do
        link_dir="$dstdir/$category"
        # Some of the links are to different dirs, in the form link_dir:link_icon
        if [[ "$link" == *:* ]]; then
            link_dir="${dstdir}/${link%%:*}"
            link="${link##*:}"
            mkdir -p "${link_dir}/${size}/"
        fi
        # Calculate link target relative to link
        link_target="$(realpath -m --relative-to "/${link_dir}/${size}/" "/${dstdir}/${category}/${size}/${target_icon}${suffix}")"
        link_dest="${link_dir}/${size}/${link}${suffix}"
        ln -sf "$link_target" "$link_dest"
    done
}

make_icon () {
    category="$1"
    srcdir="$2"
    dstdir="$3"
    icon="$4"
    source="$5"
    size="$6"
    links="$7"
    suffix="$8"

    srcfile="${srcdir}/${category}/${source}/${icon}.svg"
    dstfile="${dstdir}/${category}/${size}/${icon}${suffix}"

    if [ ! -e "$srcfile" ]; then
        :
        # echo -e "    \e[31m${icon} \e[1mMISSING\e[22m\e[0m in ${srcdir}/${source} (to build ${size})"
    else
        # If the source file is a symlink, just symlink to corresponding dst file (might not have been built yet)
        if [ -L "$srcfile" ]; then
            svgtarget="$(realpath --relative-to "$srcdir" "$srcfile")"
            target_category="${svgtarget%%/*}"
            target_filename="$(basename "$svgtarget")"
            target="$(realpath -m --relative-to "/$dstdir/$category/$size/" "/$dstdir/$target_category/$size/${target_filename%%.svg}${suffix}")"
            ln -sf "$target" "$dstfile"
        else
            # Don't build it again if already built (eg resume build job)
            if [ ! -e "$dstfile" ]; then
                if [ "$size" == scalable ]; then
                    # This is probably not the most simple version of the svg, should use one from packages instead?
                    cp "$srcfile" "$dstfile"
                else
                    # supress inkscape output except error messages
                    inkscape -z -e "$dstfile" -w "$size" -h "$size" "$srcfile" > /dev/null
                fi
            fi
        fi
        make_links "$category" "$dstdir" "$size" "$icon" "$links" "$suffix"
    fi
}

make_all () {
    # echo "Make all ($@)"
    category="$1"
    srcdir="$2"
    dstdir="$3"
    icon="$4"
    links="$5"

    # make target folders if needed
    mkdir -p $dstdir/$category/{16,22,24,32,48,64,96,scalable}

    # Make all png files in parallel
    make_icon "$category" "$srcdir" "$dstdir" "$icon" 'extra small' 16 "$links" .png &
    make_icon "$category" "$srcdir" "$dstdir" "$icon" 'extra small' 22 "$links" .png &
    make_icon "$category" "$srcdir" "$dstdir" "$icon" 'extra small' 24 "$links" .png &
    make_icon "$category" "$srcdir" "$dstdir" "$icon" 'extra small' 32 "$links" .png &
    make_icon "$category" "$srcdir" "$dstdir" "$icon" 'small'       48 "$links" .png &
    make_icon "$category" "$srcdir" "$dstdir" "$icon" '.'           64 "$links" .png &
    make_icon "$category" "$srcdir" "$dstdir" "$icon" '.'           96 "$links" .png
    make_icon "$category" "$srcdir" "$dstdir" "$icon" '.'           scalable "$links" .svg
}

theme_name=Faenza

for lstfile in *.lst; do
    category="${lstfile%%.lst}"
    echo -e "\e[32m\e[1m[ $category ]\e[0m"

    # For each non-empty line if the lstfile
    cat $lstfile | grep -v '^$' | while read line; do
        arr=($line)
        # source icon is name the first word, rest is links
        icon="${arr[0]}"
        links="${arr[@]:1}"
        echo -e "  - \e[33m$icon\e[0m -> $links"

        # Some icon names are references from different categories
        if [[ "$icon" == *:* ]]; then
            category="${icon%%:*}"
            icon="${icon##*:}"
            
        fi
        
        dstdir="build/${theme_name}"
        make_all "$category" "." "$dstdir" "$icon" "$links"

        for variant in __*; do
            srcdir="$variant/"
            # Remove underscores and capitalize variant
            variant="${variant##__}"
            variant="${variant^}"
            dstdir="build/${theme_name}-${variant}/"
            make_all "$category" "$srcdir" "$dstdir" "$icon" "$links"
        done
    done
done

# Make sure there are no broken links
find build -xtype l
find build -type d -empty -delete