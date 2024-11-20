#!/bin/bash

currentDir=$(pwd)

echo "always" | sudo tee -a /sys/kernel/mm/transparent_hugepage/enabled
echo "THP enabled"
cd $currentDir

generateTopOutput(){
        BENCHMARK_PID=$1
        TOPREDIRECT=$2
        while ps -p $BENCHMARK_PID > /dev/null;
        do
            top -p $BENCHMARK_PID -b -n 1 | awk -v pid=$BENCHMARK_PID '{print $5, $6}' | tail -1 >> $TOPREDIRECT
            sleep 10
        done
}

funcKhugeAggr(){
    echo 40960 | sudo tee -a /sys/kernel/mm/transparent_hugepage/khugepaged/pages_to_scan
    echo "Page to scan value"
    cat /sys/kernel/mm/transparent_hugepage/khugepaged/pages_to_scan
    echo 0 | sudo tee -a /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs
    echo "Scan sleep millisecs value is "
    cat /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs
}

funcKhugeDefault(){
    echo 40960 | sudo tee -a /sys/kernel/mm/transparent_hugepage/khugepaged/pages_to_scan
    echo "Page to scan value"
    cat /sys/kernel/mm/transparent_hugepage/khugepaged/pages_to_scan
    echo 100 | sudo tee -a /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs
    echo "Scan sleep millisecs value is "
    cat /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs

}

# Function to run the command and generate memory size
run_command1() {
    filename=$1
    node_number=1
    echo "Running the command nodenumber $node_number"
    CMD_PREFIX="numactl -C 6-11,54-59 -m $node_number"
    LAUNCH_CMD="$CMD_PREFIX ./$filename -N $node_number"
    REDIRECT="$currentDir/run_multipleHawkeyeHetero/$filename-$node_number.txt"
    TOPREDIRECT="$currentDir/run_multipleHawkeyeHetero/$filename-$node_number-top.txt"
    f1="/tmp/alloctest-bench$node_number.ready"
    f2="/tmp/alloctest-bench$node_number.done"
    rm $f1 &>/dev/null
    rm $f2 &>/dev/null
    echo "Iteration $i" >> $REDIRECT
    echo "Iteration $i" >> $TOPREDIRECT
    $LAUNCH_CMD >> $REDIRECT &
    BENCHMARK_PID=$!
    echo "wrting to file"
    touch $currentDir/myfile.txt
    echo $BENCHMARK_PID >> $currentDir/myfile.txt
    generateTopOutput $BENCHMARK_PID $TOPREDIRECT &
	SECONDS=0
	echo "waiting for benchmark: $BENCHMARK_PID to be ready"
	while [ ! -f $f1 ]; do
		sleep 0.1
	done
	INIT_DURATION=$SECONDS
    echo "signalling readyness to the host"
    touch $f1
    SECONDS=0
	echo "0mwaiting for benchmark to be done"
	while [ ! -f $f2 ]; do
		sleep 0.1
	done
	DURATION=$SECONDS
	echo "****success****"
    echo "Execution Time for $filename (seconds): $DURATION"
	echo -e "Execution Time (seconds): $DURATION" >> $REDIRECT
	echo -e "Initialization Time (seconds): $INIT_DURATION\n" >> $REDIRECT
       
}

run_command2() {
    filename=$1
    node_number=$2
    echo "Running the command nodenumber $node_number"
    CMD_PREFIX="numactl -c $node_number -m $node_number"
    LAUNCH_CMD="$CMD_PREFIX ./$filename $node_number"
    REDIRECT="$currentDir/run_multipleHawkeyeHetero/$filename-$node_number.txt"
    TOPREDIRECT="$currentDir/run_multipleHawkeyeHetero/$filename-$node_number-top.txt"
    f1="/tmp/alloctest-bench$node_number.ready"
    f2="/tmp/alloctest-bench$node_number.done"
    rm $f1 &>/dev/null
    rm $f2 &>/dev/null
    echo "Iteration $i" >> $REDIRECT
    echo "Iteration $i" >> $TOPREDIRECT
    $LAUNCH_CMD >> $REDIRECT &
    BENCHMARK_PID=$!
    echo "wrting to file"
    touch $currentDir/myfile1.txt
    echo $BENCHMARK_PID >> $currentDir/myfile1.txt
    echo "Benchmark PID: $BENCHMARK_PID"
    generateTopOutput $BENCHMARK_PID $TOPREDIRECT &
	SECONDS=0
	echo "waiting for benchmark: $BENCHMARK_PID to be ready"
	while [ ! -f $f1 ]; do
		sleep 0.1
	done
	INIT_DURATION=$SECONDS
    echo "signalling readyness to the host"
    touch $f1
    SECONDS=0
	echo "0mwaiting for benchmark to be done"
	while [ ! -f $f2 ]; do
		sleep 0.1
	done
	DURATION=$SECONDS
	echo "****success****"
    echo "Execution Time for $filename (seconds): $DURATION"
	echo -e "Execution Time (seconds): $DURATION" >> $REDIRECT
	echo -e "Initialization Time (seconds): $INIT_DURATION\n" >> $REDIRECT
       
}


if [ ! -d "$currentDir/run_multipleHawkeyeHetero" ]; then
    mkdir -p $currentDir/run_multipleHawkeyeHetero
fi


    for nr_to_free in 5000000 7500000 10000000 12500000; do
        rm /tmp/alloctest-bench* &>/dev/null
        rm $currentDir/myfile* &>/dev/null
        echo "Running the experiment with $filename"
        funcKhugeAggr
        sudo rmmod remove_multipleHawkeyehighToLow
        run_command1 memcached &
        echo "Now sleeping for 40 seconds"
        sleep 40
        run_command2 btree 3 &
    
        while [ ! -f /tmp/alloctest-bench3.ready ]; do
            sleep 0.1
        done
        sleep 5
        while IFS= read -r line
        do
            # Convert each line to an integer
            integer_value=$((line))
            echo "Integer: $integer_value"
        done < "$currentDir/myfile.txt"

        while IFS= read -r line
        do
            # Convert each line to an integer
            integer_value1=$((line))
            echo "Integer: $integer_value1"
        done < "$currentDir/myfile1.txt"

        echo "All values read, $integer_value, $integer_value1"
        echo "Inserting module"
        sudo insmod /home/gulshan/parth/misc-collection-master/HawkEye/modules/origBloat4.3/remove_multipleHawkeye/remove_multipleHawkeyehighToLow.ko pid=$integer_value1 pid1=$integer_value nr_to_free=$nr_to_free
        sleep 5
        funcKhugeDefault
        while [ ! -f /tmp/alloctest-bench3.done ]; do
            sleep 0.1
        done
        echo "Benchmark done for $nr_to_free"
        echo "sleeping for 100 seconds"
        sleep 100
    done
