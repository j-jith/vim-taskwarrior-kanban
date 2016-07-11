if !has('python')
	finish
endif

function! TWKanban()
python << EOF
from __future__ import absolute_import, division, print_function

import vim
import subprocess
import json
import datetime

MAX_COMPLETED = 10 # max. no. of completed tasks to display

def get_tasks(tags):

    # run taskwarrior export
    command = ['task', 'rc.json.depends.array=no', 'export'] + tags 
    data = subprocess.check_output(command) 
    data = data.decode('utf-8') # decode bytestring to string
    data = data.replace('\n','') # remove newline indicators

    # load taskwarrior export as json data
    tasks = json.loads(data)

    return tasks

def check_due_date(tasks):
    
    for task in tasks:
        if 'due' in task:
            # calculate due date in days
            due_date = datetime.datetime.strptime(task['due'], '%Y%m%dT%H%M%SZ')
            due_in_days = (due_date - datetime.datetime.utcnow()).days
            
            if due_in_days > 7: # if due after a week, remove due date
                task.pop('due', None)
            else:
                task['due'] = due_in_days

def print_table(rows):
    """print_table(rows)
    Based on https://gist.github.com/lonetwin/4721748.
    """

    vim.current.buffer[0] = 'TASKWARRIOR KANBAN BOARD'
    vim.current.buffer.append('')

    # - figure out column widths
    widths = [ len(max(columns, key=len)) for columns in zip(*rows) ]

    # - print the header
    header, data = rows[0], rows[1:]
    vim.current.buffer.append(' | '.join( format(title, "%ds" % width) for width, title in zip(widths, header) ))

    # - print the separator
    vim.current.buffer.append('-+-'.join( '-' * width for width in widths ))

    # - print the data
    for row in data:
        vim.current.buffer.append(" | ".join( format(cdata, "%ds" % width) for width, cdata in zip(widths, row) ))


def make_table(tasks_dic):

    table = [('Not Started', 'Started', 'Done')]

    l_todo = len(tasks_dic['todo'])
    l_started = len(tasks_dic['started'])
    l_completed = len(tasks_dic['completed'])

    l_max = max([l_todo, l_started, l_completed])

    for k in range(l_max):
        task_todo = {}
        task_started = {}
        task_completed = {}

        if k > l_todo-1:
            task_todo['description'] = ''
        else:
            task_todo = tasks_dic['todo'][k]

        if k > l_started-1:
            task_started['description'] = ''
        else:
            task_started = tasks_dic['started'][k]

        if k > l_completed-1:
            task_completed['description'] = ''
        else:
            task_completed = tasks_dic['completed'][k]

        table.append((task_todo['description'], task_started['description'],
                    task_completed['description']))

    return table


# get pending tasks
pending_tasks = get_tasks(['status:pending'])

# get tasks to do
todo_tasks = [task for task in pending_tasks if 'start' not in task]
# sort tasks by urgency (descending order)
todo_tasks = sorted(todo_tasks, key=lambda task: task['urgency'], reverse=True)
# check due dates
check_due_date(todo_tasks)

# get started tasks
started_tasks = [task for task in pending_tasks if 'start' in task]
# sort tasks by urgency (descending order)
started_tasks = sorted(started_tasks, key=lambda task: task['urgency'], reverse=True)
# check due dates
check_due_date(started_tasks)

# get completed tasks 
completed_tasks = get_tasks(['status:completed']) 

# master dictionary of all tasks
tasks_dic = {}
tasks_dic['todo'] = todo_tasks
tasks_dic['started'] = started_tasks
tasks_dic['completed'] = completed_tasks[:MAX_COMPLETED]

# make a table that can be passed to print_table to be printed
table = make_table(tasks_dic)

# open a new vim split
vim.command('new')
vim.command('setlocal buftype=nofile') # new buffer not associated with a file
vim.command('setlocal bufhidden=delete') # delete buffer when hidden
vim.command('setlocal noswapfile') # no swap file for buffer
vim.command('setlocal nobuflisted') # buffer is not listed

# print to newly created buffer
print_table(table)

EOF
endfunction
 
command! TWK call TWKanban()
