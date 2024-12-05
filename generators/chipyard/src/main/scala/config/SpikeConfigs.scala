package chipyard

import org.chipsalliance.cde.config.{Config}

// Configs which instantiate a Spike-simulated
// tile that interacts with the Chipyard SoC
// as a hardware core would

class SpikeConfig extends Config(
  new chipyard.WithNSpikeCores(1) ++
  new chipyard.config.AbstractConfig)

class SpikeZicntrConfig extends Config(
  new chipyard.WithSpikeZicntr ++
  new chipyard.WithNSpikeCores(1) ++
  new chipyard.config.AbstractConfig)

class dmiSpikeConfig extends Config(
  new chipyard.harness.WithSerialTLTiedOff ++                    // don't attach anything to serial-tilelink
  new chipyard.config.WithDMIDTM ++                              // have debug module expose a clocked DMI port
  new SpikeConfig)

// Avoids polling on the UART registers
class SpikeFastUARTConfig extends Config(
  new freechips.rocketchip.subsystem.WithExtMemSize((1<<30) * 4L) ++
  new chipyard.WithNSpikeCores(1) ++
  new chipyard.config.WithUART(txEntries=128, rxEntries=128) ++   // Spike sim requires a larger UART FIFO buffer,
  new chipyard.config.WithNoUART() ++                             // so we overwrite the default one
  new chipyard.config.WithUniformBusFrequencies(2) ++               // configured to be as fast as possible
  new chipyard.config.AbstractConfig)

// No L2 and a ludicrous L1D
class SpikeUltraFastConfig extends Config(
  new testchipip.soc.WithNoScratchpads ++
  new chipyard.WithSpikeTCM ++
  new chipyard.config.WithBroadcastManager ++
  new SpikeFastUARTConfig)

class dmiSpikeUltraFastConfig extends Config(
  new chipyard.config.WithNPMPs(0) ++
  new chipyard.harness.WithSerialTLTiedOff ++                    // don't attach anything to serial-tilelink
  new chipyard.config.WithDMIDTM ++                              // have debug module expose a clocked DMI port
  new SpikeUltraFastConfig)

class dmiCheckpointingSpikeUltraFastConfig extends Config(
  new chipyard.config.WithNPMPs(0) ++                            // remove PMPs (reduce non-core arch state)
  new dmiSpikeUltraFastConfig)

// Add the default firechip devices
class SpikeUltraFastDevicesConfig extends Config(
  new chipyard.harness.WithSimBlockDevice ++
  new chipyard.harness.WithLoopbackNIC ++
  new icenet.WithIceNIC ++
  new testchipip.iceblk.WithBlockDevice ++
  new SpikeUltraFastConfig)

class DTMSpike1Config extends Config(
  // new chipyard.harness.WithCospike ++
  // new chipyard.config.WithTraceIO ++
  // new freechips.rocketchip.rocket.WithDebugROB ++
  new chipyard.config.WithL2TLBs(0, 1) ++
  new chipyard.harness.WithSimBlockDevice ++                // drive block-device IOs with SimBlockDevice
  new testchipip.iceblk.WithBlockDevice ++
  //new chipyard.config.WithUARTFIFOEntries(16384, 16384) ++ // huge so minimize delay on printing
  new chipyard.config.WithNoUART ++                              // only use htif prints w/ checkpointing
  new freechips.rocketchip.subsystem.WithExtMemSize(BigInt(256) << 20) ++
  //new freechips.rocketchip.rocket.WithCease(false) ++
  new chipyard.config.WithNPMPs(0) ++
  new chipyard.harness.WithSerialTLTiedOff() ++
  new chipyard.config.WithDMIDTM() ++
  new chipyard.WithNSpikeCores(1) ++
  //new chipyard.config.WithUniformBusFrequencies(2) ++               // configured to be as fast as possible
  new freechips.rocketchip.subsystem.WithoutTLMonitors ++
  new chipyard.config.AbstractConfig)
