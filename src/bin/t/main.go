package main

import (
	"fmt"
	"io"
	"os"

	"p8/asm"
	"p8/vm"
)

func FprintRegs(out io.Writer, vm *vm.VM) {
	fmt.Fprintf(out, "pc=%016x", vm.PC())

	for i := uint8(0); i < 16; i++ {
		if i%4 == 0 {
			fmt.Fprintln(out)
		} else {
			fmt.Fprint(out, " ")
		}
		fmt.Fprintf(out, "$%x=%016x", i, vm.R(i))
	}
	fmt.Fprintln(out)
	fmt.Fprintf(out, "tsc=%d ttl=%d\n", vm.TSC, vm.TTL)
}

func PrintRegs(vm *vm.VM) { FprintRegs(os.Stdout, vm) }

func main() {
	v := vm.New(4096 * 8)                   // 8 pages
	v.Load(asm.AssembleFile("a.asm"), 4096) // load at page 1

	e := v.ResumeAt(4096)
	fmt.Printf("e=%d\n", e)
	PrintRegs(v)

	e = v.Resume()
	fmt.Printf("e=%d\n", e)
	PrintRegs(v)
}
