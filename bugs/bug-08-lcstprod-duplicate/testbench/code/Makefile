all:
	verilator --cc tb.sv --exe - <<< 'int main(){}'
	make -C obj_dir -f Vtb.mk 2>/dev/null
	./obj_dir/Vtb
