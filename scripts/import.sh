next () {

read -p "Continue (y/n)?" choice
case "$choice" in 
  y|Y ) echo "yes";;
  n|N ) echo "no";;
  * ) echo "invalid";;
esac

}

echo "start"

next
echo "weiter"

next
echo "ziel"  && exit 1
