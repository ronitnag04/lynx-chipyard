package chipyard.config

import chisel3._

import org.chipsalliance.cde.config.{Field, Parameters, Config}
import freechips.rocketchip.tile._
import freechips.rocketchip.diplomacy._

import gemmini._

import chipyard.{TestSuitesKey, TestSuiteHelper}

/**
 * Map from a tileId to a particular RoCC accelerator
 */
case object MultiRoCCKey extends Field[Map[Int, Seq[Parameters => LazyRoCC]]](Map.empty[Int, Seq[Parameters => LazyRoCC]])

/**
 * Config fragment to enable different RoCCs based on the tileId
 */
class WithMultiRoCC extends Config((site, here, up) => {
  case BuildRoCC => site(MultiRoCCKey).getOrElse(site(TileKey).tileId, Nil)
})

/**
 * Assigns what was previously in the BuildRoCC key to specific harts with MultiRoCCKey
 * Must be paired with WithMultiRoCC
 */
class WithMultiRoCCFromBuildRoCC(harts: Int*) extends Config((site, here, up) => {
  case BuildRoCC => Nil
  case MultiRoCCKey => up(MultiRoCCKey) ++ harts.distinct.map { i =>
    (i -> up(BuildRoCC))
  }
})

class WithMultiRoCCGemmini[T <: Data : Arithmetic, U <: Data, V <: Data](
  harts: Int*)(gemminiConfig: GemminiArrayConfig[T,U,V] = GemminiConfigs.defaultConfig) extends Config((site, here, up) => {
  case MultiRoCCKey => up(MultiRoCCKey) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      implicit val q = p
      val gemmini = LazyModule(new Gemmini(gemminiConfig))
      gemmini
    }))
  }
})

// other multirocc
import protoacc._
import compressacc._
import aes._
import freechips.rocketchip.rocket.{TLBConfig}

class WithMultiRoCCSnappyCompressor(harts: Int*) extends Config((site, here, up) => {
  case CompressAccelTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case MultiRoCCKey => up(MultiRoCCKey) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val compress_accel_compressor = LazyModule.apply(new SnappyCompressor(OpcodeSet.custom1)(p))
      compress_accel_compressor
    }))
  }
})

class WithMultiRoCCSnappyDecompressor(harts: Int*) extends Config((site, here, up) => {
  case CompressAccelTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case MultiRoCCKey => up(MultiRoCCKey) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val compress_accel_decompressor = LazyModule.apply(new SnappyDecompressor(OpcodeSet.custom0)(p))
      compress_accel_decompressor
    }))
  }
})

class WithMultiRoCCZstdCompressor(harts: Int*) extends Config((site, here, up) => {
  case CompressAccelTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case ZstdCompressorKey => Some(ZstdCompressorConfig(
    queDepth = 4
    ))
  case HufCompressUnrollCnt => 2
  case HufCompressDicBuilderProcessedStatBytesPerCycle => 2
  case HufCompressDicBuilderProcessedHeaderBytesPerCycle => 4
  case FSECompressDicBuilderProcessedStatBytesPerCycle => 4
  case RemoveSnappyFromMergedAccelerator => true
  case CompressAccelPrintfEnable => true
  case MultiRoCCKey => up(MultiRoCCKey) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val zstd_compressor = LazyModule(new ZstdCompressor(OpcodeSet.custom1)(p))
      zstd_compressor
    }))
  }
})

class WithMultiRoCCZstdDecompressor(harts: Int*) extends Config((site, here, up) => {
  case CompressAccelTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case ZstdDecompressorCmdQueDepth => 4
  case HufDecompressDecompAtOnce => 12
  case NoSnappy => true
  case CompressAccelPrintfEnable => true
  case MultiRoCCKey => up(MultiRoCCKey) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val zstd_decompressor = LazyModule.apply(new ZstdDecompressor(OpcodeSet.custom0)(p))
      zstd_decompressor
    }))
  }
})

class WithMultiRoCCProtoAccelSer(harts: Int*) extends Config((site, here, up) => {
  case ProtoTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case MultiRoCCKey => up(MultiRoCCKey) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val protoaccser = LazyModule.apply(new ProtoAccelSerializer(OpcodeSet.custom3)(p))
      protoaccser
    }))
  }
})

class WithMultiRoCCProtoAccelDeser(harts: Int*) extends Config((site, here, up) => {
  case ProtoTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case MultiRoCCKey => up(MultiRoCCKey) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val protoacc = LazyModule.apply(new ProtoAccel(OpcodeSet.custom2)(p))
      protoacc
    }))
  }
})

class WithAccumulatorRoCC(op: OpcodeSet = OpcodeSet.custom1) extends Config((site, here, up) => {
  case BuildRoCC => up(BuildRoCC) ++ Seq((p: Parameters) => {
    val accumulator = LazyModule(new AccumulatorExample(op, n = 4)(p))
    accumulator
  })
})

class WithCharacterCountRoCC(op: OpcodeSet = OpcodeSet.custom2) extends Config((site, here, up) => {
  case BuildRoCC => up(BuildRoCC) ++ Seq((p: Parameters) => {
    val counter = LazyModule(new CharacterCountExample(op)(p))
    counter
  })
})
