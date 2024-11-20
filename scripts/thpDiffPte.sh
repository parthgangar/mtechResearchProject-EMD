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
    khugepaged_maxpte=$2
    CMD_PREFIX="numactl -c 7 -m 7"
    LAUNCH_CMD="$CMD_PREFIX ./$filename"
    REDIRECT="$currentDir/thpDiffPte/$filename.txt"
    TOPREDIRECT="$currentDir/thpDiffPte/$filename-top.txt"
    echo "Starting the experiment with maxpte value $khugepaged_maxpte" >> $REDIRECT
    echo "Starting the experiment with maxpte value $khugepaged_maxpte" >> $TOPREDIRECT
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
	    funcKhugeDefault
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
    echo "Done doing the experiments with maxpte value $khugepaged_maxpte" >> $REDIRECT
    echo "Done doing the experiments with maxpte value $khugepaged_maxpte" >> $TOPREDIRECT
}

if [ ! -d "$currentDir/thpDiffPte" ]; then
    mkdir -p $currentDir/thpDiffPte
fi

for filename in "${my_list[@]}"; do
    echo "Running the experiment with $filename"
        for khugepaged_maxpte in 511 510 509 508 504 448 384 256 128; do
            # Set the max pte none value
            echo $khugepaged_maxpte | sudo tee -a /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none
            echo "Max pte none value is"
            cat /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none
            echo
            # Run the command with the current THP status
            run_command $filename $khugepaged_maxpte
        done
done
