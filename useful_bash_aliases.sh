# Regular UNIX commands
alias psw='\ps --pid 1,2 --ppid 1,2 -N --forest --format="euser:16,pid:7,pcpu:7,pmem:7,etime:13,stat:5,wchan:17,cmd"'
alias dfw='\df -ah --output="source,fstype,size,used,avail,pcent,target" --exclude-type={sysfs,proc,devtmpfs,devpts,tmpfs,securityfs,cgroup2,cgroup,pstore,efivarfs,binfmt_misc,tracefs,debugfs,configfs,hugetlbfs,bpf,mqueue,squashfs,cgmfs,fusectl,fuse.gvfsd-fuse,gvfsd-fuse,overlay,nsfs,rpc_pipefs,autofs,none}'
alias dmesg='\dmesg -Tx'
alias dmesg-f='\dmesg -Tx --follow'
alias lsblk='\lsblk --output="name,type,size,fstype,label,mountpoint"'
alias sl='\ss --tcp --udp --processes --all --resolve --oneline'
alias less='\less -FSRXc'

# SLURM commands
alias show_down_nodes='\sinfo --list-reasons --sort="+H" --format="%20n %8T %19H %11u %E"' # <--- adjust fields width for your cluster
alias sinf='\sinfo --sort="-P,-T" --format="%20P %.4D %10T"'                               # <--- adjust fields width for your cluster
alias sque='\squeue --sort="-T,-S" -o "%.7i %14u %12j %18a %19S %5D %10M %2t %R"'          # <--- adjust fields width for your needs
