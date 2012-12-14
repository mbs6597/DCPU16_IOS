//task Struct Offsets/Values
#define task_common_name    0
#define task_sched_prev     5
#define task_sched_next     6
#define task_saved_sp       7
#define task_msg_count      8
#define task_msg_queue      9
#define task_stdout_pid    30
#define task_stdin_pid     31

#define task_size          32
#define task_qty_messages   4

//pending_message struct offsets
#define msg_sender    0
#define msg_message   1
#define msg_p1        2
#define msg_p2        3
#define msg_p3        4
#define msg_size      5

#define CODE_OK              1
#define CODE_STATE_ERROR     2
#define CODE_EXECUTION_ERROR 3
#define CODE_UNSUPPORTED     4

#define ERROR_NONE           0
#define ERROR_IO             1
#define ERROR_LOGICAL        2
#define ERROR_UNAVAILABLE    3