#!/bin/bash

currentDir=$(pwd)
my_list=("btree" "memcached")

echo "always" | sudo tee -a /sys/kernel/mm/transparent_hugepage/enabled
echo "THP enabled"
echo 511 | sudo tee -a /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none
echo "Max pte none value is"
cat /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none
echo
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
    echo 1 | sudo tee -a /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs
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
run_command() {
    filename=$1
    CMD_PREFIX="numactl -c 7 -m 7"
    LAUNCH_CMD="$CMD_PREFIX ./$filename"
    REDIRECT="$currentDir/run_hawkeyehighToLow/$filename.txt"
    TOPREDIRECT="$currentDir/run_hawkeyehighToLow/$filename-top.txt"
    for nr_to_free in 3000000 4000000 5000000 6000000; do
    echo "Setting the nr_to_free value to $nr_to_free" >> $REDIRECT
    echo "Running the command in 1 iteration" >> $REDIRECT
    for i in 1; do
        rm /tmp/alloctest-bench0.ready &>/dev/null
	    rm /tmp/alloctest-bench0.done &> /dev/null
        echo "Iteration $i" >> $REDIRECT
        echo "Iteration $i" >> $TOPREDIRECT
        funcKhugeAggr
        $LAUNCH_CMD >> $REDIRECT &
        BENCHMARK_PID=$!
        echo "Benchmark PID: $BENCHMARK_PID"
        echo "Running top for maxpte value $khugepaged_maxpte, iteration $i" >> $TOPREDIRECT
        generateTopOutput $BENCHMARK_PID $TOPREDIRECT &
	    SECONDS=0
	    echo "waiting for benchmark: $BENCHMARK_PID to be ready"
	    while [ ! -f /tmp/alloctest-bench0.ready ]; do
		    sleep 0.1
	    done
	    INIT_DURATION=$SECONDS
        echo "signalling readyness to the host"
        touch /tmp/alloctest-bench0.ready
	    echo "Initialization Time (seconds): $INIT_DURATION"
        sleep 2
	    funcKhugeDefault
        sudo rmmod remove_highToLow
        echo "Loading kernel module"
        sudo insmod /home/gulshan/parth/misc-collection-master/HawkEye/modules/origBloat4.3/remove_hawkeye/remove_highToLow.ko pid=$BENCHMARK_PID nr_to_free=$nr_to_free >> $REDIRECT &
        SECONDS=0
	    echo "0mwaiting for benchmark to be done"
	    while [ ! -f /tmp/alloctest-bench0.done ]; do
		    sleep 0.1
	    done
	    DURATION=$SECONDS
	    echo "****success****"
        echo "Execution Time (seconds): $DURATION"
	    echo -e "Execution Time (seconds): $DURATION" >> $REDIRECT
	    echo -e "Initialization Time (seconds): $INIT_DURATION\n" >> $REDIRECT
        
        echo "Done with iteration $i" >> $REDIRECT
        echo "Done with iteration $i" >> $TOPREDIRECT
    
    done
    done
    
}

if [ ! -d "$currentDir/run_hawkeyehighToLow" ]; then
    mkdir -p $currentDir/run_hawkeyehighToLow
fi

for filename in "${my_list[@]}"; do
    echo "Running the experiment with $filename"
    run_command $filename 
done
