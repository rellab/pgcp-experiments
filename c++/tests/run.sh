docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj g++ -O2 -std=c++17 main.cpp -o app \
  -I ./ -I/usr/local/include -I/usr/local/include/obj \
  -L/usr/local/lib -lcudd
docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj ./app $*

