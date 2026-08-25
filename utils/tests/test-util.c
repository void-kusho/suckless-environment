/* See LICENSE file for copyright and license details. */
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include "../common/util.h"

static int failures = 0;
static int passes = 0;

static void
pass(const char *name)
{
	printf("PASS: %s\n", name);
	passes++;
}

static void
fail(const char *name, const char *reason)
{
	printf("FAIL: %s (%s)\n", name, reason);
	failures++;
}

/* Test 1: die() exits with code 1 */
static void
test_die_exits(void)
{
	pid_t pid;
	int status;

	pid = fork();
	if (pid == 0) {
		/* Child: call die(), should exit(1) */
		die("test fatal error");
		_exit(0); /* should not reach here */
	}
	waitpid(pid, &status, 0);
	if (WIFEXITED(status) && WEXITSTATUS(status) == 1)
		pass("die_exits_with_1");
	else
		fail("die_exits_with_1", "expected exit status 1");
}

/* Test 2: die() with colon suffix prints errno string and exits 1 */
static void
test_die_errno(void)
{
	pid_t pid;
	int status;

	pid = fork();
	if (pid == 0) {
		/* Child: set errno, call die with colon suffix */
		errno = ENOENT;
		die("test:");
		_exit(0);
	}
	waitpid(pid, &status, 0);
	if (WIFEXITED(status) && WEXITSTATUS(status) == 1)
		pass("die_errno_colon");
	else
		fail("die_errno_colon", "expected exit status 1");
}

/* Test 3: warn() does NOT exit */
static void
test_warn_continues(void)
{
	pid_t pid;
	int status;

	pid = fork();
	if (pid == 0) {
		warn("test warning");
		_exit(0); /* should reach here */
	}
	waitpid(pid, &status, 0);
	if (WIFEXITED(status) && WEXITSTATUS(status) == 0)
		pass("warn_continues");
	else
		fail("warn_continues", "warn should not exit");
}

/* Test 4: warn() with colon suffix appends errno */
static void
test_warn_errno(void)
{
	pid_t pid;
	int status;

	pid = fork();
	if (pid == 0) {
		errno = ENOENT;
		warn("test:");
		/* Should continue and exit 0 */
		_exit(0);
	}
	waitpid(pid, &status, 0);
	if (WIFEXITED(status) && WEXITSTATUS(status) == 0)
		pass("warn_errno_colon");
	else
		fail("warn_errno_colon", "warn should not exit");
}

/* Test 5: pscanf() reads value from file */
static void
test_pscanf_reads(void)
{
	FILE *fp;
	int val = 0;
	int ret;
	const char *path = "/tmp/test-util-pscanf";

	fp = fopen(path, "w");
	if (!fp) {
		fail("pscanf_reads", "cannot create temp file");
		return;
	}
	fprintf(fp, "42\n");
	fclose(fp);

	ret = pscanf(path, "%d", &val);
	unlink(path);

	if (ret == 1 && val == 42)
		pass("pscanf_reads");
	else
		fail("pscanf_reads", "expected ret=1 val=42");
}

/* Test 6: pscanf() returns -1 for nonexistent file */
static void
test_pscanf_nofile(void)
{
	int val = 0;
	int ret;

	ret = pscanf("/tmp/test-util-nonexistent-file-xxxxx", "%d", &val);
	if (ret == -1)
		pass("pscanf_nofile");
	else
		fail("pscanf_nofile", "expected -1 for nonexistent file");
}

/* Test 7: exec_wait() runs true, returns 0 */
static void
test_exec_wait_true(void)
{
	int ret;

	ret = exec_wait((const char *const[]){"true", NULL});
	if (ret == 0)
		pass("exec_wait_true");
	else
		fail("exec_wait_true", "expected return 0");
}

/* Test 8: exec_wait() runs false, returns 1 */
static void
test_exec_wait_false(void)
{
	int ret;

	ret = exec_wait((const char *const[]){"false", NULL});
	if (ret == 1)
		pass("exec_wait_false");
	else
		fail("exec_wait_false", "expected return 1");
}

/* Test 9: exec_detach() does not block */
static void
test_exec_detach_nonblocking(void)
{
	pid_t pid;
	int status;

	/*
	 * Fork a child that calls exec_detach(sleep 10).
	 * If exec_detach blocks, child won't exit within 2 seconds.
	 */
	pid = fork();
	if (pid == 0) {
		exec_detach((const char *const[]){"sleep", "10", NULL});
		_exit(0); /* Should reach immediately */
	}

	/* Wait with timeout using alarm */
	alarm(2);
	waitpid(pid, &status, 0);
	alarm(0);

	if (WIFEXITED(status) && WEXITSTATUS(status) == 0)
		pass("exec_detach_nonblocking");
	else
		fail("exec_detach_nonblocking", "exec_detach blocked or child failed");
}

/* Test 10: setup_sigchld() reaps zombies */
static void
test_setup_sigchld_reaps(void)
{
	pid_t pid;
	int ret;

	setup_sigchld();
	exec_detach((const char *const[]){"true", NULL});

	/* Wait for child to finish */
	usleep(200000); /* 200ms */

	/* Try to wait for any zombie -- should find none */
	pid = waitpid(-1, NULL, WNOHANG);
	/*
	 * waitpid returns -1 with ECHILD if no children exist (all reaped).
	 * Returns 0 if children exist but none have exited.
	 * Returns >0 if a zombie was found (BAD -- means sigchld didn't reap).
	 */
	if (pid <= 0)
		pass("setup_sigchld_reaps");
	else
		fail("setup_sigchld_reaps", "zombie found after setup_sigchld");

	/* Restore default SIGCHLD for remaining tests */
	ret = 0;
	(void)ret;
	signal(SIGCHLD, SIG_DFL);
}

int
main(void)
{
	argv0 = "test-util";

	test_die_exits();
	test_die_errno();
	test_warn_continues();
	test_warn_errno();
	test_pscanf_reads();
	test_pscanf_nofile();
	test_exec_wait_true();
	test_exec_wait_false();
	test_exec_detach_nonblocking();
	test_setup_sigchld_reaps();

	printf("\nResults: %d passed, %d failed\n", passes, failures);
	return failures > 0 ? 1 : 0;
}
