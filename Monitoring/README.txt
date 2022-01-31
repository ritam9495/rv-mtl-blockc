::For Debian OS on a server without sudo permission::

You can download one of the stable releases then follow the following commands:

tar zxvf z3-4.8.10.tar.gz
cd z3-z3-4.8.10
python scripts/mk_make.py
cd build
make -j60 examples

This will create all the necessary files and directories. To run the ./cpp_example:
either:
setenv LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:.
then you can run ./cpp_example
or:
env LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:. ./cpp_example everytime

g++ -D_MP_INTERNAL -DNDEBUG -D_EXTERNAL_RELEASE -D_USE_THREAD_LOCAL  -std=c++17 -fvisibility=hidden -fvisibility-inlines-hidden -c -mfpmath=sse -msse -msse2 -O3 -D_LINUX_ -fPIC -D_LINUX_  -o example.o  -I../src/api -I../src/api/c++ ../examples/c++/example.cpp

g++ -o cpp_example  example.o  libz3.so -lpthread

env LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:. ./cpp_example

Note: You should make examples and use the statements to compile and run according to your system. It's system dependant!!