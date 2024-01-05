set -e
dir=`dirname $0`
g++ $dir/controller.cpp -std=c++14 -I /usr/include/ -L /usr/lib/ -lserial -lpthread -o $dir/fpga
