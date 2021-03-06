errHalt = 1
errAddr = 2
errDeath = 3
todo = -> console.error "todo"

pageSize = 4096
pageShift = 12

pageId = (a) -> a >> pageShift
pageHead = (i) -> i << pageShift
pageAlign = (a) -> a >> pageShift << pageShift
pageOff = (a) -> a & ((1 << pageShift) - 1)

a16 = (p) -> p >> 1 << 1
a32 = (p) -> p >> 2 << 2
a64 = (p) -> p >> 3 << 3

# A page of pageSize
Page = ->
    buffer = new ArrayBuffer(pageSize)
    view = new DataView(buffer)

    this.i8 = (p) -> view.getInt8 p
    this.u8 = (p) -> view.getUint8 p
    this.i16 = (p) -> view.getInt16 a16(p)
    this.u16 = (p) -> view.getUint16 a16(p)
    this.i32 = (p) -> view.getInt32 a32(p)
    this.u32 = (p) -> view.getUint32 a32(p)
    this.f64 = (p) -> view.getFloat64 a64(p)
    
    this.p18 = (p, v) -> view.setInt8 p, v
    this.pu8 = (p, v) -> view.setUint8 p, v
    this.pi16 = (p, v) -> view.setInt16 a16(p), v
    this.pu16 = (p, v) -> view.setUint16 a16(p), v
    this.pi32 = (p, v) -> view.setInt32 a32(p), v
    this.pu32 = (p, v) -> view.setUint32 a32(p), v
    this.pf64 = (p, v) -> view.setFloat64 f64(p), v

    return # Page

# A page that has the same interface but does nothing
# on either writing or reading
NoopPage = ->
    r0 = (p) -> 0
    noop = (p, v) -> return
    this.i8 = this.u8 = this.i16 = this.u16 = r
    this.u32 = this.f64 = r

    this.pi8 = this.pu8 = this.pi16 = this.pu16 = noop
    this.pi32 = this.pf64 = noop

    return # NoopPage

# A organic structure that stores all the opcodes
# It supports querying, instruction parsing, instruction making
# and instruction printing functions
Risc = ->
    thiz = this
    byname = {}
    bycode = {}
    names = []
    nop = 0
    
    makeInst = (x, p, q, i) ->
        ret = 0
        ret = ret | (i & 0xffff)
        ret = ret | ((q & 0x7) << 16)
        ret = ret | ((p & 0x7) << 19)
        ret = ret | ((x & 0x7) << 22)
        return ret
    
    add = (name, str, make, parse) ->
        code = nop
        op = {
            code: code
            name: name
            exec: -> return
            str: str
            make: make
            parse: parse
        }
        names.push name
        byname[name] = op
        bycode[nop] = op
        thiz[name] = (a, b, c, d, e) ->
            (make a, b, c, d, e) | (code << 25)
        nop = nop + 1
        return

    add0 = (name) ->
        add name,
            (p) -> name
            -> makeInst 0, 0, 0, 0
            (line) -> todo()
    add0Ims = (name) ->
        add name,
            (p) -> name + " " + p.ims
            (ims) -> makeInst 0, 0, 0, ims
            (line) -> todo()

    add0 "halt"
    add0Ims "printi"

    this.byname = (name) ->
        if name of byname then byname[name] else false
    this.names = names
    
    return # Risc

Vm = ->
    thiz = this
    pages = {}
    readonlys = {}
    nreg = 8
    iregs = new Int32Array nreg
    uregs = new Uint32Array iregs
    e = 0
    fakePage = new Page()

    page = (a) ->
        id = pageId(a)
        if id of pages then return pages[id]
        e = errAddr
        return fakePage
    wpage = (a) ->
        id = pageId(a)
        if id of readonlys
            e = errAddr
            return fakePage
        if id of pages then return pages[id]
        e = errAddr
        return fakePage

    c16 = (a) -> e = errAddr if a16(a) != a; return
    c32 = (a) -> e = errAddr if a32(a) != a; return
    c64 = (a) -> e = errAddr if a64(a) != a; return

    i8 = (a) -> page(a).i8(pageOff a)
    u8 = (a) -> page(a).u8(pageOff a)
    i16 = (a) -> c16 a; page(a).i16(pageOff a)
    u16 = (a) -> c16 a; page(a).u16(pageOff a)
    i32 = (a) -> c16 a; page(a).i32(pageOff a)
    u32 = (a) -> c32 a; page(a).u32(pageOff a)
    f64 = (a) -> c64 a; page(a).f64(pageOff a)
    
    pi8 = (a, v) -> wpage(a).pi8(pageOff a)
    pu8 = (a, v) -> wpage(a).pu8(pageOff a)
    pi16 = (a, v) -> c16 a; wpage(a).pi16(pageOff a, v)
    pu16 = (a, v) -> c16 a; wpage(a).pu16(pageOff a, v)
    pi32 = (a, v) -> c32 a; wpage(a).pi32(pageOff a, v)
    pu32 = (a, v) -> c32 a; wpage(a).pu32(pageOff a, v)
    pf64 = (a, v) -> c64 a; wpage(a).pf64(pageOff a, v)

    risc = new Risc()
    execs = {}
    strs = {}
    o = (name, exec) ->
        ret = risc.byname name
        if ret == false then return
        code = ret.code
        execs[code] = exec
        strs[code] = ret.str
        return
    o "halt", (p) -> e = errHalt
    o "printi", (p) -> thiz.printi p.ims

    exec = (inst, oldPc) ->
        code = (inst >> 25) & 0x7f
        parts =
            code: code
            x: (inst >> 22) & 0x7
            p: (inst >> 19) & 0x7
            q: (inst >> 16) & 0x7
            imu: (inst & 0xffff)
            ims: (inst << 16 >> 16)
        if code of execs
            thiz.log oldPc, inst, strs[code](parts)
            execs[code](parts)
        else
            thiz.log oldPc, inst, "noop"
        return

    step = ->
        inst = u32(thiz.pc)
        oldPc = thiz.pc
        if e != 0 then return
        thiz.pc = a32(thiz.pc + 4)
        exec inst, oldPc
        uregs[0] = 0

        thiz.tsc += 1
        if thiz.ttl > 0
            thiz.ttl -= 1
            if thiz.ttl == 0
                e = errDeath
        return

    # public fields
    this.error = -> e
    this.pc = pageHead 1
    this.ttl = 0
    this.tsc = 0
    this.mapPage = (a, p, ro) ->
        id = pageId a
        if id == 0 then return
        pages[id] = p
        if ro then readonlys[id] = true
        return
    this.resume = -> e = 0; step() while e == 0; e
    this.step = -> e = 0; step(); e
    this.printi = (i) -> console.log i; return
    this.log = (pc, inst, s) -> return

    return # Vm

# A page writer that writes into a page.
PageWriter = (page) ->
    p = page
    thiz = this
    this.off = 0
    offinc = (i) -> thiz.off = pageOff(thiz.off + i)
    this.i8 = (v) -> p.pi8 this.off, v; offinc 1; return
    this.u8 = (v) -> p.pu8 this.off, v; offinc 1; return
    this.i16 = (v) -> p.pi16 this.off, v; offinc 2; return
    this.u16 = (v) -> p.pu16 this.off, v; offinc 2; return
    this.i32 = (v) -> p.pi16 this.off, v; offinc 4; return
    this.u32 = (v) -> p.pu32 this.off, v; offinc 4; return
    this.f64 = (v) -> p.pf64 this.off, v; offinc 8; return

    return # PageWriter

# A very simple assembler that writes instructions in a page
PageAsm = (page) ->
    p = page
    writer = new PageWriter(page)
    thiz = this
    risc = new Risc()
    labels = {}

    for name in risc.names
        thiz[name] = (a, b, c, d, e) ->
            writer.u32(risc[name](a, b, c, d, e))

    this.label = (lab) ->
        console.log lab, writer.off
        labels[lab] = writer.off
        return

    return # PageAsm

exports.p8 =
    errHalt: errHalt
    errAddr: errAddr
    errDeath: errDeath
    Risc: Risc
    Vm: Vm
    PageWriter: PageWriter
    PageAsm: PageAsm
    Page: Page
    pageHead: pageHead

