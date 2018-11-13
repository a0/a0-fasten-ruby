clear
echo -n "c:demo amartoq$ "
osascript -e 'activate application "GIPHY CAPTURE"'
osascript -e 'tell application "System Events" to keystroke "0" using command down'
osascript -e 'activate application "Terminal"'
sleep 1

echo "head -20 deploy_fasten.rb" | pv -qL $[15+(-4 + RANDOM%10)]
head -20 deploy_fasten.rb
echo
sleep 0.5
echo -n "c:demo amartoq$ "
echo "fasten --name deploy --summary -f deploy_fasten.rb" | pv -qL $[15+(-4 + RANDOM%10)]
sleep 1
fasten --name deploy --summary -f deploy_fasten.rb
echo -n "c:demo amartoq$ "
sleep 4
echo "clear" | pv -qL $[15+(-4 + RANDOM%10)]
osascript -e 'activate application "GIPHY CAPTURE"'
osascript -e 'tell application "System Events" to keystroke "0" using command down'

# echo "fasten --name deploy --summary --ui console -f deploy_fasten.rb" | pv -qL $[15+(-4 + RANDOM%10)]
# fasten --name deploy --summary --ui console -f deploy_fasten.rb

rm -f *.testfile
