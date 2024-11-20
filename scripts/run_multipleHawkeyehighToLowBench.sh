#!/bin/bash

currentDir=$(pwd)

my_list=("microBench_var1" "microBench_var2")
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
    LAUNCH_CMD="$CMD_PREFIX ./$filename $node_number"
    REDIRECT="$currentDir/run_multipleHawkeyehighToLow/$filename-$node_number.txt"
    TOPREDIRECT="$currentDir/run_multipleHawkeyehighToLow/$filename-$node_number-top.txt"
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
    echo "Execution Time (seconds): $DURATION"
	echo -e "Execution Time (seconds): $DURATION" >> $REDIRECT
	echo -e "Initialization Time (seconds): $INIT_DURATION\n" >> $REDIRECT
       
}

run_command2() {
    filename=$1
    node_number=$2
    echo "Running the command nodenumber $node_number"
    CMD_PREFIX="numactl -c $node_number -m $node_number"
    LAUNCH_CMD="$CMD_PREFIX ./$filename $node_number"
    REDIRECT="$currentDir/run_multipleHawkeyehighToLow/$filename-$node_number.txt"
    TOPREDIRECT="$currentDir/run_multipleHawkeyehighToLow/$filename-$node_number-top.txt"
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
    echo "Execution Time (seconds): $DURATION"
	echo -e "Execution Time (seconds): $DURATION" >> $REDIRECT
	echo -e "Initialization Time (seconds): $INIT_DURATION\n" >> $REDIRECT
       
}

run_command3() {
    filename=$1
    node_number=$2
    echo "Running the command nodenumber $node_number"
    CMD_PREFIX="numactl -c $node_number -m $node_number"
    LAUNCH_CMD="$CMD_PREFIX ./$filename $node_number"
    REDIRECT="$currentDir/run_multipleHawkeyehighToLow/$filename-$node_number.txt"
    TOPREDIRECT="$currentDir/run_multipleHawkeyehighToLow/$filename-$node_number-top.txt"
    f1="/tmp/alloctest-bench$node_number.ready"
    f2="/tmp/alloctest-bench$node_number.done"
    rm $f1 &>/dev/null
    rm $f2 &>/dev/null
    echo "Iteration $i" >> $REDIRECT
    echo "Iteration $i" >> $TOPREDIRECT
    $LAUNCH_CMD >> $REDIRECT &
    BENCHMARK_PID=$!
    echo "wrting to file"
    touch $currentDir/myfile2.txt
    echo $BENCHMARK_PID >> $currentDir/myfile2.txt
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
    echo "Execution Time (seconds): $DURATION"
	echo -e "Execution Time (seconds): $DURATION" >> $REDIRECT
	echo -e "Initialization Time (seconds): $INIT_DURATION\n" >> $REDIRECT
       
}

run_command4() {
    filename=$1
    node_number=$2
    echo "Running the command nodenumber $node_number"
    CMD_PREFIX="numactl -c $node_number -m $node_number"
    LAUNCH_CMD="$CMD_PREFIX ./$filename $node_number"
    REDIRECT="$currentDir/run_multipleHawkeyehighToLow/$filename-$node_number.txt"
    TOPREDIRECT="$currentDir/run_multipleHawkeyehighToLow/$filename-$node_number-top.txt"
    f1="/tmp/alloctest-bench$node_number.ready"
    f2="/tmp/alloctest-bench$node_number.done"
    rm $f1 &>/dev/null
    rm $f2 &>/dev/null
    echo "Iteration $i" >> $REDIRECT
    echo "Iteration $i" >> $TOPREDIRECT
    $LAUNCH_CMD >> $REDIRECT &
    BENCHMARK_PID=$!
    echo "wrting to file"
    touch $currentDir/myfile3.txt
    echo $BENCHMARK_PID >> $currentDir/myfile3.txt
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
    echo "Execution Time (seconds): $DURATION"
	echo -e "Execution Time (seconds): $DURATION" >> $REDIRECT
	echo -e "Initialization Time (seconds): $INIT_DURATION\n" >> $REDIRECT
       
}

if [ ! -d "$currentDir/run_multipleHawkeyehighToLow" ]; then
    mkdir -p $currentDir/run_multipleHawkeyehighToLow
fi


for filename in "${my_list[@]}"; do
    for nr_to_free in 1000000 1500000 2000000 2500000 3000000 4000000; do
        rm /tmp/alloctest-bench* &>/dev/null
        rm $currentDir/myfile* &>/dev/null
        echo "Running the experiment with $filename"
        funcKhugeAggr
        sudo rmmod remove_multipleHawkeyehighToLow
        run_command1 $filename &
        run_command2 $filename 3 &
        run_command3 $filename 5 &
        run_command4 $filename 7 &
        while [ ! -f /tmp/alloctest-bench1.ready ]; do
            sleep 0.1
        done
        sleep 5
        funcKhugeDefault
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

        while IFS= read -r line
        do
            # Convert each line to an integer
            integer_value2=$((line))
            echo "Integer: $integer_value2"
        done < "$currentDir/myfile2.txt"

        while IFS= read -r line
        do
            # Convert each line to an integer
            integer_value3=$((line))
            echo "Integer: $integer_value3"
        done < "$currentDir/myfile3.txt"
        echo "All values read, $integer_value, $integer_value1, $integer_value2, $integer_value3"
        echo "Inserting module"
        sudo insmod /home/gulshan/parth/misc-collection-master/HawkEye/modules/origBloat4.3/remove_multipleHawkeye/remove_multipleHawkeyehighToLow.ko pid=$integer_value pid1=$integer_value1 pid2=$integer_value2 pid3=$integer_value3 nr_to_free=$nr_to_free
        while [ ! -f /tmp/alloctest-bench1.done ]; do
            sleep 0.1
        done
        echo "Benchmark done for $nr_to_free"
        echo "sleeping for 200 seconds"
        sleep 200
    done
done