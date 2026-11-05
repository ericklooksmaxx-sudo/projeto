const { SmartBuffer } = require("smart-buffer")

const OpCodes = [
    "Move",
    "LoadK",
    "LoadBool",
    "LoadNil",
    "GetUpval",
    "GetGlobal",
    "GetTable",
    "SetGlobal",
    "SetUpval",
    "SetTable",
    "NewTable",
    "Self",
    "Add",
    "Sub",
    "Mul",
    "Div",
    "Mod",
    "Pow",
    "Unm",
    "Not",
    "Len",
    "Concat",
    "Jmp",
    "Eq",
    "Lt",
    "Le",
    "Test",
    "TestSet",
    "Call",
    "TailCall",
    "Return",
    "ForLoop",
    "ForPrep",
    "TForLoop",
    "SetList",
    "Close",
    "Closure",
    "VarArg"
]

const OpCodeTypes = [
    "AB",   // Move
    "ABx",  // LoadK
    "ABC",  // LoadBool
    "AB",   // LoadNil
    "AB",   // GetUpval
    "ABx",  // GetGlobal
    "ABC",  // GetTable
    "ABx",  // SetGlobal
    "AB",   // SetUpval
    "ABC",  // SetTable
    "ABC",  // NewTable
    "ABC",  // Self
    "ABC",  // Add
    "ABC",  // Sub
    "ABC",  // Mul
    "ABC",  // Div
    "ABC",  // Mod
    "ABC",  // Pow
    "AB",   // Unm
    "AB",   // Not
    "AB",   // Len
    "ABC",  // Concat
    "sBx",  // Jmp
    "ABC",  // Eq
    "ABC",  // Lt
    "ABC",  // Le
    "AC",   // Test
    "ABC",  // TestSet
    "ABC",  // Call
    "ABC",  // TailCall
    "AB",   // Return
    "AsBx", // ForLoop
    "AsBx", // ForPrep
    "AC",   // TForLoop
    "ABC",  // SetList
    "A",    // Close
    "ABx",  // Closure
    "AB"    // VarArg
]

function maskSize(value, size) {
    value = value & ((1 << size) - 1)
    return value
}

/**
 * 
 * @param {SmartBuffer} buffer
 */
function writeString(buffer, str) {
    buffer.writeUInt32LE(str.length + 1)
    buffer.writeStringNT(str, "ascii")
}

function writeHeader(buffer) {
    buffer.writeString("\x1bLua")
    buffer.writeUInt8(0x51)
    buffer.writeUInt8(0)
    buffer.writeUInt8(1)
    buffer.writeUInt8(4)
    buffer.writeUInt8(4)
    buffer.writeUInt8(4)
    buffer.writeUInt8(8)
    buffer.writeUInt8(0)
}

function writeChunkHeader(buffer, chunk) {
    writeString(buffer, chunk.Top ? "@Peak#7550" : "")

    buffer.writeUInt32LE(0)
    buffer.writeUInt32LE(0)
    buffer.writeUInt8(0)
    buffer.writeUInt8(chunk.Parameters)
    buffer.writeUInt8(chunk.VarArg ? 3 : 2)
    //console.log(chunk.Registers)
    //buffer.writeUInt8(255) // cba to count the number of registers becuaes idk if its right
    
    let max_stack_size = 2

    for (let i = 0; i < chunk.Instructions.length; i++) {
        const inst = chunk.Instructions[i];
        const type = OpCodeTypes[inst.OpCode] || "";
        if (inst.A !== undefined) max_stack_size = Math.max(max_stack_size, inst.A + 1);
        if (type === "AB" || type === "ABC") {
            if (inst.B !== undefined && inst.B < 256) max_stack_size = Math.max(max_stack_size, inst.B + 1);
        }
        if (type === "ABC" || type === "AC") {
            if (inst.C !== undefined && inst.C < 256) max_stack_size = Math.max(max_stack_size, inst.C + 1);
        }
    }

    max_stack_size = Math.max(max_stack_size + 4, 16);
    buffer.writeUInt8(max_stack_size)

} 

function  writeConstant(buffer, constant) {
    //console.log("const.", typeof constant, ":", constant)
    switch (typeof constant) {
        case "boolean":
            buffer.writeUInt8(1)
            buffer.writeUInt8(Number(constant))
            break;
        case "number":
            buffer.writeUInt8(3)
            buffer.writeDoubleLE(constant)
            break;
        case "string":
            buffer.writeUInt8(4)
            writeString(buffer, constant)
            break;
        case "object":
            buffer.writeUInt8(0)
            break;
        default: 
            throw (`Attempt to write constant with invalid type "${typeof constant}"`)
    }
}  

function writeInstruction(buffer, instruction) {
    if (instruction.OpCode === 28) {
        if (instruction.B > 255) instruction.B = 0;
        if (instruction.C > 255) instruction.C = 1;
    }
    let data = instruction.OpCode

    switch (instruction.Type) {
        case "A":
            data = data | maskSize(instruction.A, 8) << 6;
            break;
        case "AB":
            data = data | maskSize(instruction.A, 8) << 6;
            data = data | maskSize(instruction.B, 9) << 23;
            break;
        case "AC":
            data = data | maskSize(instruction.A, 8) << 6;
            data = data | maskSize(instruction.C, 9) << 14;
            break;
        case "ABC":
            if (instruction.OpCode === 28 || instruction.OpCode === 29) { // Call, TailCall
                if (instruction.B >= 256) instruction.B = 1;
                if (instruction.C >= 256) instruction.C = 1;
            }
            data = data | maskSize(instruction.A, 8) << 6;
            data = data | maskSize(instruction.B, 9) << 23;
            data = data | maskSize(instruction.C, 9) << 14;
            break;
        case "ABx":
            data = data | maskSize(instruction.A, 8) << 6;
            data = data | maskSize(instruction.B, 18) << 14;
            break;
        case "AsBx":
            data = data | maskSize(instruction.A, 8) << 6;
            data = data | maskSize(instruction.B + 131071, 18) << 14;
            break;
        case "sBx":
            data = data | maskSize(instruction.B + 131071, 18) << 14;
            break;
    }
    
    data = data >>> 0 // Unsigned Right Shift Operator (convert to uint32 cus life sucks)
    buffer.writeUInt32LE(data);
}

function writeChunkFooter(buffer) {
    buffer.writeUInt32LE(0)
    buffer.writeUInt32LE(0)
    buffer.writeUInt32LE(0)
}

function writeLength(buffer, length) {
    buffer.writeUInt32LE(length)
}

function sterilize(topchunk) {
    const bytecode = new SmartBuffer()
    
    writeHeader(bytecode)

    function write(chunk) {
        writeChunkHeader(bytecode, chunk)

        writeLength(bytecode, chunk.Instructions.length)

        for (let i = 0; i < chunk.Instructions.length; i++) {
            writeInstruction(bytecode, chunk.Instructions[i])
        }

        writeLength(bytecode, chunk.Constants.length)

        for (let i = 0; i < chunk.Constants.length; i++) {
            writeConstant(bytecode, chunk.Constants[i])
        }

        writeLength(bytecode, chunk.Prototypes.length)

        for (let i = 0; i < chunk.Prototypes.length; i++) {
            write(chunk.Prototypes[i])
        }

        writeChunkFooter(bytecode)
    }

    write(topchunk)

    return bytecode.toBuffer()
}

module.exports = {sterilize, OpCodeTypes, OpCodes}