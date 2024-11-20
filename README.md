# EMD - Fair and Efficient Memory De-bloating of Transparent Huge Pages

The virtual memory abstraction simplifies programming and enhances portability but requires the processor to translate virtual addresses to physical addresses which can be expensive. To speed up the virtual-to-physical address translation, processors store recently used addresses in Translation Lookaside Buffers (TLBs) and use huge (aka large) pages to reduce TLB misses. For example, the x86 architecture supports 2MB and 1GB huge pages. However, fully harnessing the performance benefits of huge pages requires robust operating system support. For example, huge pages are notorious for creating memory bloat -- a phenomenon wherein an application is allocated more physical memory than it needs. This leads to a tradeoff between performance and memory efficiency wherein application performance can be improved at the potential expense of allocating extra physical memory. Ideally, a system should manage this trade-off dynamically depending on the availability of physical memory at runtime.

We address these issues with** EMD (Efficient Memory De-bloating)**. The key insight in EMD is that different regions in an application's address space exhibit different amounts of memory bloat. Consequently, the tradeoff between memory efficiency and performance varies significantly within a given application e.g., we find that memory bloat is typically concentrated in certain regions of an application address space, and de-bloating such regions leads to minimal performance impact. Following this insight, EMD employs a prioritization scheme for fine-grained, efficient, and fair reclamation of memory bloat. We show that doing this improves performance by up to 69\% compared to HawkEye, the state-of-the-art OS-based huge page management system, and nearly eliminates fairness pathologies in current systems.
