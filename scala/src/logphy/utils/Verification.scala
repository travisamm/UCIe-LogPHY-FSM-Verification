// /*
//   Description:
//     Shared verification layers for LogPHY modules.
// */
// package edu.berkeley.cs.uciedigital.logphy

// import chisel3.layer.{Convention, Layer}

// // The Assert, Debug, and Cover layers are nested under the Verification layer.
// object Verification extends Layer(Convention.Bind) {
//   object Assert extends Layer(Convention.Bind)
//   object Debug extends Layer(Convention.Bind)
//   object Cover extends Layer(Convention.Bind)
// }
