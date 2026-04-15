// Minimal sbt project for elaborating LogPHY modules to SystemVerilog.
//
// Pulls only Chisel 7.8 from Maven Central — no Berkeley-internal JARs needed.
// Excludes tilelink/, phy/, and SidebandLinkSerdes.scala, which are the only
// files in the source tree that depend on RocketChip/Diplomacy.

ThisBuild / scalaVersion := "2.13.18"
ThisBuild / version      := "0.0.1"
ThisBuild / organization := "edu.berkeley.cs"

lazy val root = (project in file("."))
  .settings(
    name := "ucie-logphy-elab",

    libraryDependencies += "org.chipsalliance" %% "chisel" % "7.8.0",
    addCompilerPlugin(
      "org.chipsalliance" %% "chisel-plugin" % "7.8.0" cross CrossVersion.full
    ),

    scalacOptions ++= Seq(
      "-language:reflectiveCalls",
      "-deprecation",
      "-feature",
      "-Xcheckinit",
    ),

    // Point at the existing sources one level up.
    Compile / scalaSource := baseDirectory.value / ".." / "scala" / "src",

    // Exclude everything that depends on RocketChip / Diplomacy:
    //   tilelink/  — uses Diplomacy (LazyModule, LazyModuleImp, etc.)
    //   phy/       — uses freechips.rocketchip.util.{AsyncQueue, AsyncQueueParams}
    //   SidebandLinkSerdes.scala — same AsyncQueue dep
    Compile / unmanagedSources / excludeFilter :=
      new SimpleFileFilter(f =>
        f.getPath.contains("/tilelink/") ||
        f.getPath.contains("/phy/") ||
        f.getName == "SidebandLinkSerdes.scala"
      ),
  )
