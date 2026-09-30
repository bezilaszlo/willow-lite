typedef unsigned long u64;
typedef unsigned int u32;
typedef unsigned short u16;
typedef long i64;

struct ts { i64 sec; i64 nsec; };
struct pollfd { int fd; short events; short revents; };
struct sockaddr_in { u16 family; u16 port; u32 addr; char zero[8]; };

static i64 sys(i64 n, i64 a, i64 b, i64 c, i64 d, i64 e)
{
	register i64 x8 __asm__("x8") = n;
	register i64 x0 __asm__("x0") = a;
	register i64 x1 __asm__("x1") = b;
	register i64 x2 __asm__("x2") = c;
	register i64 x3 __asm__("x3") = d;
	register i64 x4 __asm__("x4") = e;

	__asm__ volatile("svc 0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4) : "memory");
	return x0;
}

static u64 len(const char *s)
{
	u64 n = 0;

	while (s[n])
		n++;
	return n;
}

static i64 now(void)
{
	struct ts t;

	sys(113, 1, (i64)&t, 0, 0, 0);
	return t.sec;
}

static int klog(int fd, const char *msg)
{
	if (fd >= 0)
		sys(64, fd, (i64)msg, len(msg), 0, 0);
	return 0;
}

static void reboot_bootloader(int kfd)
{
	klog(kfd, "willow-lite: deadman expired, rebooting to bootloader\n");
	sys(81, 0, 0, 0, 0, 0);
	sys(142, 0xfee1dead, 0x28121969, 0xA1B2C3D4, (i64)"bootloader", 0);
	for (;;)
		sys(101, (i64)&(struct ts){ 60, 0 }, 0, 0, 0, 0);
}

static u64 atou(const char *s)
{
	u64 v = 0;

	while (*s >= '0' && *s <= '9')
		v = v * 10 + (u64)(*s++ - '0');
	return v;
}

int c_start(u64 *sp)
{
	int argc = (int)sp[0];
	char **argv = (char **)(sp + 1);
	u64 secs, port;
	i64 deadline;
	int one = 1, s, kfd;
	struct sockaddr_in a = { 2, 0, 0, { 0 } };

	if (argc < 3)
		return 2;
	secs = atou(argv[1]);
	port = atou(argv[2]);
	kfd = (int)sys(56, -100, (i64)"/dev/kmsg", 1, 0, 0);
	a.port = (u16)(((port & 0xff) << 8) | (port >> 8));

	s = (int)sys(198, 2, 1, 0, 0, 0);
	if (s < 0)
		reboot_bootloader(kfd);
	sys(208, s, 1, 2, (i64)&one, 4);
	if (sys(200, s, (i64)&a, sizeof(a), 0, 0) < 0 || sys(201, s, 4, 0, 0, 0) < 0)
		reboot_bootloader(kfd);

	klog(kfd, "willow-lite: deadman armed\n");
	deadline = now() + (i64)secs;
	for (;;) {
		struct pollfd p = { s, 1, 0 };
		struct ts t = { 1, 0 };
		i64 left = deadline - now();

		if (left <= 0)
			reboot_bootloader(kfd);
		if (left < 1)
			t.sec = left;
		if (sys(73, (i64)&p, 1, (i64)&t, 0, 8) > 0) {
			char buf[16] = { 0 };
			int c = (int)sys(202, s, 0, 0, 0, 0);

			if (c < 0)
				continue;
			sys(63, c, (i64)buf, 15, 0, 0);
			sys(57, c, 0, 0, 0, 0);
			if (buf[0] == 'o' && buf[1] == 'k') {
				klog(kfd, "willow-lite: deadman disarmed by host\n");
				return 0;
			}
			if (buf[0] == 'r' && buf[1] == 'b')
				reboot_bootloader(kfd);
			if (buf[0] == 'h' && buf[1] == 'o')
				deadline = now() + (i64)secs;
		}
	}
}

__asm__(".globl _start\n_start:\n\tmov x0, sp\n\tbl c_start\n\tmov x8, #93\n\tsvc 0\n");
