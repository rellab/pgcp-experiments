docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj g++ -O2 -std=c++17 main.cpp -o app \
  -I ./ -I/usr/local/include -I/usr/local/include/obj \
  -L/usr/local/lib -lcudd

mkdir -p results

docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj ./app data/binary015.csv 4 10 | tee results/experiment2_015.txt
docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj ./app data/binary014.csv 4 10 | tee results/experiment2_014.txt
docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj ./app data/binary013.csv 4 10 | tee results/experiment2_013.txt
docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj ./app data/binary012.csv 4 10 | tee results/experiment2_012.txt
docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj ./app data/binary011.csv 4 10 | tee results/experiment2_011.txt
docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj ./app data/binary010.csv 4 10 | tee results/experiment2_010.txt
docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj ./app data/binary009.csv 4 10 | tee results/experiment2_009.txt
docker run --rm -v $PWD:/workspace -w /workspace cudd-cpp:obj ./app data/binary008.csv 4 10 | tee results/experiment2_008.txt

