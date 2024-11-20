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

struct tty_struct *out = NULL;
char *buff;

int pid = 0;
module_param(pid, int, 0);
int sleep = 10000;
module_param(sleep, int, 0);
unsigned long nr_to_free = 1000000;
module_param(nr_to_free, ulong, 0);

unsigned long nr_hugepages_broken = 0;

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
    snprintf(buff, BUFF_LEN, "target: %ld recovered: %ld hugePagesBroken: %ld", nr_to_free, nr_recovered, nr_hugepages_broken);
    write_output();
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
static bool remove_bloat(struct task_struct *task)
{
    struct vm_area_struct *vma = NULL;
    struct mm_struct *mm = NULL;
    struct page *page;
    unsigned long nr_recovered = 0;
    unsigned long start, end, addr;

    mm = get_task_mm(task);
    if (!mm)
        goto out;
    mm->disable_khugepaged = 1;
    int num = 90;  
    /* traverse the list of all vma regions */
    while(nr_recovered < nr_to_free){
        int threshold = (num * 512)/100;
        // printk(KERN_INFO"Threshold: %d\n", threshold);
        for (vma = mm->mmap; vma; vma = vma->vm_next)
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
                if(nr_zero > 0){
                    nr_hugepages_broken += 1;
                }
                nr_recovered += nr_zero;
                put_page(page);
                addr += PAGE_SIZE * 512;
                if (nr_recovered > nr_to_free){
                    goto inner_break;
                } 
            }
        }
        num = num - 10;
    }
inner_break:
    mmput(mm);
    print_recovery_info(nr_to_free, nr_recovered);
    return true;

out:
    snprintf(buff, BUFF_LEN, "Unable to locate task mm for pid: %d", task->pid);
    write_output();
    return  false;
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
        pid_struct = find_get_pid(pid);
        if (!pid_struct)
            goto out;

        task = pid_task(pid_struct, PIDTYPE_PID);
        if (!task)
            goto out;

        /* Calculate bloat. */
        remove_bloat(task);
    write_output();
    vfree(buff);
    return 0;
out:
    snprintf(buff, BUFF_LEN, "Unable to find task: %d\n", pid);
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
