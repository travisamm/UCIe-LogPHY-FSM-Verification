package edu.berkeley.cs.uciedigital.logphy

import edu.berkeley.cs.uciedigital.interfaces._
import chisel3._
import chisel3.util._

/*
  Description: 
    Simple that module takes care of conducting the pl_clk_req/lp_clk_ack handshake 
    in a centralized place. Interfacing with the module is done through the `ctrl` signals.
*/

class RDIClockHandshakeHandler() extends Module {

  // Module specific state
  object State extends ChiselEnum {
    val sIDLE, sWAIT_ACK_ASSERT, sACTIVE_HOLD, sWAIT_ACK_DEASSERT = Value
  }

  val io = IO(new Bundle {
    val ctrl = new Bundle {
      val startHandshake = Input(Bool())
      val releaseReq = Input(Bool())
      val doneHandshake = Output(Bool())            
      val inIdle = Output(Bool())
    }      
    val rdi = new Bundle {
      val plClkReq = Output(Bool())
      val lpClkAck = Input(Bool())
    }          
  })  

  val currentState = RegInit(State.sIDLE)
  val nextState = WireInit(currentState)
  currentState  := nextState

  io.rdi.plClkReq := false.B
  io.ctrl.doneHandshake := false.B  // doneHandshake goes high when lpClkAck goes HIGH

  // Once inIdle cycles back to sIDLE, after start, then handshake fully compelete.
  io.ctrl.inIdle := currentState === State.sIDLE       

  switch(currentState) {
    is(State.sIDLE) {
      when(io.ctrl.startHandshake) {
        nextState := State.sWAIT_ACK_ASSERT
      }
    } 
    is(State.sWAIT_ACK_ASSERT) {      
      io.rdi.plClkReq := true.B
      when(io.rdi.lpClkAck) {
        nextState := State.sACTIVE_HOLD
      }
    }
    is(State.sACTIVE_HOLD) {
      io.rdi.plClkReq := true.B
      io.ctrl.doneHandshake := true.B
      // Rule 6, 7, and 9: We stay here until the FSM signals releases
      when(io.ctrl.releaseReq) {        
        nextState := State.sWAIT_ACK_DEASSERT
      }
    }
    is(State.sWAIT_ACK_DEASSERT) {
      // Rule 3: pl_clk_req MUST de-assert before lp_clk_ack
      io.rdi.plClkReq := false.B
      when(!io.rdi.lpClkAck) {
        nextState := State.sIDLE
      }      
    }
  }
}