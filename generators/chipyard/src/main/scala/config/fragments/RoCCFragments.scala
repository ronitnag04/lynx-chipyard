package chipyard.config

import chisel3._

import org.chipsalliance.cde.config.{Field, Parameters, Config}
import freechips.rocketchip.tile._
import freechips.rocketchip.diplomacy._

import hwacha.{Hwacha}
import gemmini._

import chipyard.{TestSuitesKey, TestSuiteHelper}

/**
 * Map from a hartId to a particular RoCC accelerator
 */
case object MultiRoCCKey extends Field[Map[Int, Seq[Parameters => LazyRoCC]]](Map.empty[Int, Seq[Parameters => LazyRoCC]])

/**
 * Config fragment to enable different RoCCs based on the hartId
 */
class WithMultiRoCC extends Config((site, here, up) => {
  case BuildRoCC => site(MultiRoCCKey).getOrElse(site(TileKey).hartId, Nil)
})

/**
 * Assigns what was previously in the BuildRoCC key to specific harts with MultiRoCCKey
 * Must be paired with WithMultiRoCC
 */
class WithMultiRoCCFromBuildRoCC(harts: Int*) extends Config((site, here, up) => {
  case BuildRoCC => Nil
  case MultiRoCCKey => up(MultiRoCCKey, site) ++ harts.distinct.map { i =>
    (i -> up(BuildRoCC, site))
  }
})

/**
 * Config fragment to add Hwachas to cores based on hart
 *
 * For ex:
 *   Core 0, 1, 2, 3 have been defined earlier
 *     with hartIds of 0, 1, 2, 3 respectively
 *   And you call WithMultiRoCCHwacha(0,1)
 *   Then Core 0 and 1 will get a Hwacha
 *
 * @param harts harts to specify which will get a Hwacha
 */
class WithMultiRoCCHwacha(harts: Int*) extends Config(
  new chipyard.config.WithHwachaTest ++
  new Config((site, here, up) => {
    case MultiRoCCKey => {
      up(MultiRoCCKey, site) ++ harts.distinct.map{ i =>
        (i -> Seq((p: Parameters) => {
          val hwacha = LazyModule(new Hwacha()(p))
          hwacha
        }))
      }
    }
  })
)

class WithHwachaTest extends Config((site, here, up) => {
  case TestSuitesKey => (tileParams: Seq[TileParams], suiteHelper: TestSuiteHelper, p: Parameters) => {
    up(TestSuitesKey).apply(tileParams, suiteHelper, p)
    import hwacha.HwachaTestSuites._
    suiteHelper.addSuites(rv64uv.map(_("p")))
    suiteHelper.addSuites(rv64uv.map(_("vp")))
    suiteHelper.addSuite(rv64sv("p"))
    suiteHelper.addSuite(hwachaBmarks)
    "SRC_EXTENSION = $(base_dir)/hwacha/$(src_path)/*.scala" + "\nDISASM_EXTENSION = --extension=hwacha"
  }
})

/**
  * The MultiRoCCGemmini fragment functions similarly to the
  * WithMultiRoCCHwacha fragment defined above
  */
class WithMultiRoCCGemmini[T <: Data : Arithmetic, U <: Data, V <: Data](
  harts: Int*)(gemminiConfig: GemminiArrayConfig[T,U,V] = GemminiConfigs.defaultConfig) extends Config((site, here, up) => {
  case MultiRoCCKey => up(MultiRoCCKey, site) ++ harts.distinct.map { i =>
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
  case MultiRoCCKey => up(MultiRoCCKey, site) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val compress_accel_compressor = LazyModule.apply(new SnappyCompressor(OpcodeSet.custom1)(p))
      compress_accel_compressor
    }))
  }
})

class WithMultiRoCCSnappyDecompressor(harts: Int*) extends Config((site, here, up) => {
  case CompressAccelTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case MultiRoCCKey => up(MultiRoCCKey, site) ++ harts.distinct.map { i =>
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
  case MultiRoCCKey => up(MultiRoCCKey, site) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val zstd_compressor = LazyModule(new ZstdCompressor(OpcodeSet.custom1)(p))
      zstd_compressor
    }))
  }
})

class WithMultiRoCCZstdDecompressor(harts: Int*) extends Config((site, here, up) => {
  case CompressAccelTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case ZstdDecompressorCmdQueDepth => 4
  case HufDecompressDecompAtOnce => 4
  case NoSnappy => true
  case CompressAccelPrintfEnable => true
  case MultiRoCCKey => up(MultiRoCCKey, site) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val zstd_decompressor = LazyModule.apply(new ZstdDecompressor(OpcodeSet.custom0)(p))
      zstd_decompressor
    }))
  }
})

class WithAES192(base_addr: BigInt, depth: BigInt, dev_name: String) extends Config((site, here, up) => {
  case PeripheryAES192Key => up(PeripheryAES192Key, site) :+ AES192Params(base_addr, depth, dev_name)
})

class WithMultiRoCCProtoAccelSer(harts: Int*) extends Config((site, here, up) => {
  case ProtoTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case MultiRoCCKey => up(MultiRoCCKey, site) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val protoaccser = LazyModule.apply(new ProtoAccelSerializer(OpcodeSet.custom3)(p))
      protoaccser
    }))
  }
})

class WithMultiRoCCProtoAccelDeser(harts: Int*) extends Config((site, here, up) => {
  case ProtoTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case MultiRoCCKey => up(MultiRoCCKey, site) ++ harts.distinct.map { i =>
    (i -> Seq((p: Parameters) => {
      val protoacc = LazyModule.apply(new ProtoAccel(OpcodeSet.custom2)(p))
      protoacc
    }))
  }
})
