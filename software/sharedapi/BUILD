package(default_visibility = ["//visibility:public"])

cc_library(
	name = "helpers",
	hdrs = [
		":helpers.h",
	],
	srcs = [
		":helpers.c"
	],
	alwayslink = True,
)

cc_library(
	name = "rocc",
	hdrs = [
		":rocc.h",
	],
	alwayslink = True,
)

cc_library(
	name = "rerocc",
	hdrs = [
		":rerocc.h",
	],
	deps = [
		":rocc"
	],
	alwayslink = True,
)

cc_library(
	name = "rocc_proto",
	hdrs = [
		":proto_rocc.h",
	],
	srcs = [
		":proto_rocc.c"
	],
	deps = [
		":rocc",
		":helpers"
	],
	alwayslink = True,
)

cc_library(
	name = "rocc_compress",
	hdrs = [
		":compress_rocc.h",
	],
	srcs = [
		":compress_rocc.c"
	],
	deps = [
		":rocc",
		":helpers"
	],
	alwayslink = True,
)

cc_library(
	name = "rocc_crypto",
	hdrs = [
		":crypto_rocc.h",
	],
	srcs = [
		":crypto_rocc.c",
	],
	deps = [
		":rocc",
		":helpers"
	],
	alwayslink = True,
)

cc_library(
	name = "rerocc_scheduler",
	hdrs = [
		":rerocc_scheduler.h",
	],
	srcs = [
		":rerocc_scheduler.c"
	],
	deps = [
		":rerocc",
		":helpers"
	],
	alwayslink = True,
)
