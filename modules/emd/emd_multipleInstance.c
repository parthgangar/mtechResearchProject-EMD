#include <linux/module.h>	/* Needed by all modules */
#include <linux/kernel.h>	/* Needed for KERN_INFO */
#include <linux/pid.h>
#include <linux/mm.h>
#include <linux/tty.h>
#include <asm/pgtable.h>
#include <linux/delay.h>
#include <linux/slab.h>
#include <linux/vmalloc.h>
#include <linux/highmem.h>

#define BUFF_LEN	1024
#define NUM_INSTANCES 4
#define NUM_LOCAL_HP_RECOVERED 1000

struct tty_struct *out = NULL;
char *buff;

int pid = 0;
module_param(pid, int, 0);
int pid1 = 0;
module_param(pid1, int, 0);
int pid2 = 0;
module_param(pid2, int, 0);
int pid3 = 0;
module_param(pid3, int, 0);
int sleep = 1000;
module_param(sleep, int, 0);
unsigned long nr_to_free = 1000000;
module_param(nr_to_free, ulong, 0);

unsigned long nr_recovered = 0;
unsigned long nr_hugepages_broken[NUM_INSTANCES] = {0};

int process_bucket[NUM_INSTANCES][11] = {0};

int priority_value=100;
struct vm_area_struct *current_vma[NUM_INSTANCES];
bool is_vma_dead[NUM_INSTANCES];
int count_vma_dead = 0;

/* declaration for kernel functions exported manually */
struct page *follow_page_custom(struct vm_area_struct *vma,
        unsigned long addr, unsigned int foll_flags);
void zap_page_range(struct vm_area_struct *vma, unsigned long start,
                unsigned long size, struct zap_details *details);

static inline void write_output(void)
{
    out->driver->ops->write(out, buff, strlen(buff));
    out->driver->ops->write(out, "\015\012", 2);
}

static inline void write_output_nonewline(void)
{
    out->driver->ops->write(out, buff, strlen(buff));
}

static void print_recovery_info(unsigned long nr_to_free, unsigned long nr_recovered)
{
    snprintf(buff, BUFF_LEN, "target: %ld recovered: %ld ", nr_to_free, nr_recovered);
}

static void print_bloat_info(unsigned long nr_to_free, unsigned long nr_recovered)
{
    int i=0,j=0;
    for(i=0;i<NUM_INSTANCES;i++){
        for(j=0;j<11;j++){
            trace_printk("Process: %d, bloat_perc: %d to %d, count: %d\n", i, j * 10, (j+1)*10, process_bucket[i][j]);
        }
        trace_printk("Total number of HP recovered for process %d: %ld\n", i, nr_hugepages_broken[i]);
    }
    trace_printk("target: %ld recovered: %ld ", nr_to_free, nr_recovered);
}


static bool is_page_zero(u8 *addr)
{
    u8 *ptr_curr = (u8 *)addr;
    u8 *ptr_end = ptr_curr + PAGE_SIZE;
    u8 val;

    while (ptr_curr < ptr_end) {
        val = *ptr_curr;
        if (val)
            return false;
        ptr_curr++;
    }
    return true;
}

/*
 * hpage must be a transparent huge page
 */
static int count_zero_pages(struct page *hpage)
{
    void *haddr;
    u8 *hstart, *hend, *addr;
    int nr_zero_pages = 0;

    haddr = kmap_atomic(hpage);
    hstart = (u8 *)haddr;
    hend = hstart + HPAGE_PMD_SIZE;
    /* zero checking logic */
    for (addr = hstart; addr < hend; addr += PAGE_SIZE) {
        if (is_page_zero(addr))
            nr_zero_pages += 1;
    }
    kunmap_atomic(haddr);
    return nr_zero_pages;
}

/*
 * hpage must be a transparent huge page
 */
static void remove_zero_pages(struct page *hpage, struct vm_area_struct *vma,
                    unsigned long start)
{
    void *haddr;
    u8 *hstart, *hend, *addr;

    haddr = kmap_atomic(hpage);
    hstart = (u8 *)haddr;
    hend = hstart + HPAGE_PMD_SIZE;
    /* zero checking logic */
    for (addr = hstart; addr < hend; addr += PAGE_SIZE, start += PAGE_SIZE) {
        if (is_page_zero(addr)) {
            zap_page_range(vma, start, PAGE_SIZE, NULL);
        }
    }
    kunmap_atomic(haddr);
}

/*
 * Traverse each page of given task and see how many pages
 * contain only-zeroes---this gives us a good enough indication.
 * on the upper bound of memory bloat.
 */
static bool remove_bloat(struct task_struct *task, int process_itr)
{
    struct vm_area_struct *vma = NULL;
    struct mm_struct *mm = NULL;
    struct page *page;
    unsigned long start, end, addr;
    unsigned long nr_local_hp_recovered = 0;

    mm = get_task_mm(task);
    if (!mm)
        goto out;
    mm->disable_khugepaged = 1;

    /* traverse the list of all vma regions */
        int threshold = (priority_value * 512)/100;
        int buck_index = priority_value / 10;
        // printk(KERN_INFO"Threshold: %d\n", threshold);
        for (vma = current_vma[process_itr]; vma; vma = vma->vm_next)
        {
            start = (vma->vm_start + ~HPAGE_PMD_MASK) & HPAGE_PMD_MASK;
            end = vma->vm_end & HPAGE_PMD_MASK;

            /* examine each huge page region */
            for (addr = start; addr < end;) {
                page = follow_page_custom(vma, addr, FOLL_GET);
                if (!page) {
                    addr += PAGE_SIZE;
                    continue;
                }
                if (!PageTransHuge(page)) {
                    put_page(page);
                    addr += PAGE_SIZE;
                    continue;
                }
                int nr_zero = 0;
                nr_zero += count_zero_pages(page);
                if(nr_zero < threshold){
                    put_page(page);
                    addr += PAGE_SIZE * 512;
                    continue;
                }
                remove_zero_pages(page, vma, addr);
                nr_hugepages_broken[process_itr] += 1;
                nr_local_hp_recovered += 1;
                process_bucket[process_itr][buck_index] += 1;
                nr_recovered += nr_zero;
                put_page(page);
                addr += PAGE_SIZE * 512;
                if(nr_local_hp_recovered > NUM_LOCAL_HP_RECOVERED || nr_recovered > nr_to_free){
                    trace_printk("Local HP recovered: %ld for process %d\n", nr_local_hp_recovered,process_itr);
                    current_vma[process_itr] = vma;
                    goto inner_break;
                } 
            }
        }
        //vma end is reached
        is_vma_dead[process_itr] = true;
        count_vma_dead += 1;
    
inner_break:
    
    mmput(mm);
    print_recovery_info(nr_to_free, nr_recovered);
    write_output();
    return true;

out:
    snprintf(buff, BUFF_LEN, "Unable to locate task mm for pid: %d", task->pid);
    write_output();
    return  false;
}

static bool initialize_func(struct task_struct *task, int process_itr)
{
    struct vm_area_struct *vma = NULL;
    struct mm_struct *mm = NULL;

    mm = get_task_mm(task);
    if (!mm)
        goto out;

    current_vma[process_itr] = mm->mmap;
    mmput(mm);
    is_vma_dead[process_itr] = false;
    return true;

out:
    trace_printk("Error in initializing VMA for process %d", process_itr);
    return false;
}

static int check_process_bloat(void)
{
    struct task_struct *task = NULL;
    struct pid *pid_struct = NULL;

    /*
     * This is a one time operation. Hence, not performance critical.
     * Moreover, we may need to allocate large buffer than kmalloc can
     * provide. Hence, it is safe to use vmalloc here.
     */
    buff = vmalloc(BUFF_LEN);
    if (!buff) {
        snprintf(buff, BUFF_LEN, "Unable to allocate vmalloc buffer");
        write_output();
        return -ENOMEM;
    }

    memset(buff, 0, BUFF_LEN);

    int process_itr = 0;
    int pid_list[NUM_INSTANCES] = {pid, pid1, pid2, pid3};

    while (nr_recovered < nr_to_free){

        trace_printk("Running for priority value: %d\n", priority_value);
        trace_printk("nr_recovered: %ld, nr_to_free: %ld\n", nr_recovered, nr_to_free); 
        for(process_itr = 0; process_itr < NUM_INSTANCES ; process_itr++)
        {
            if(pid_list[process_itr] == 0){
                trace_printk("Process %d not found\n, moving on to next process's starting vma", process_itr);
                continue;
            }
            pid_struct = find_get_pid(pid_list[process_itr]);
            if (!pid_struct)
                goto out;

            task = pid_task(pid_struct, PIDTYPE_PID);
            if (!task)
                goto out;

            if(!initialize_func(task, process_itr))
                goto out;
            
            trace_printk("Process %d VMA and flag initialized\n", process_itr);
        } // end of for loop
        trace_printk("VMA and flag initialized for all processes, onto debloating\n");
        trace_printk("Resetting count_vma_dead\n");
        count_vma_dead = 0;
        trace_printk("count_vma_dead: %d\n", count_vma_dead);

        while(count_vma_dead != NUM_INSTANCES)
        {
            for(process_itr = 0; process_itr < NUM_INSTANCES ; process_itr++)
            {
                if(pid_list[process_itr] == 0){
                    trace_printk("Process %d not found\n, moving on to next one", process_itr);
                    continue;
                }
                pid_struct = find_get_pid(pid_list[process_itr]);
                if (!pid_struct)
                    goto out;

                task = pid_task(pid_struct, PIDTYPE_PID);
                if (!task)
                    goto out;
                
                if(is_vma_dead[process_itr])
                    continue;

                /* Calculate bloat. */
                remove_bloat(task, process_itr);
                trace_printk("Process %d debloated, nr_recovered: %ld\n", process_itr, nr_recovered);
                if(nr_recovered > nr_to_free)
                    goto out;

            } // end of for loop
        } // end of while loop
        trace_printk("All vmas dead for all processes, so decrementing priority value\n");
        priority_value -= 10;
    } // end of main while loop
    
    print_bloat_info(nr_to_free, nr_recovered);
    write_output();
    vfree(buff);
    return 0;
out:
    snprintf(buff, BUFF_LEN, "Unable to find task: %d\n", pid);
    print_bloat_info(nr_to_free, nr_recovered);
    write_output();
    vfree(buff);
    return -1;
}

int init_module(void)
{
    out = current->signal->tty;
    check_process_bloat();
    return 0;
}

void cleanup_module(void)
{
    printk(KERN_INFO"Module Exiting\n");
}

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Parth Gangar");
