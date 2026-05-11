// Minimal sbt project for elaborating LogPHY modules to SystemVerilog.
//
// Pulls only Chisel 7.8 from Maven Central, so no Berkeley-internal JARs are
// required. The generate_logphy_sv.sh script sets UCIE_ELAB_SOURCES to the
// small source closure needed by the requested target; this keeps unrelated
// in-progress Chisel files from breaking independent elaborations.

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

    Compile / unmanagedSourceDirectories := Seq(
      baseDirectory.value / ".." / "scala" / "src",
      baseDirectory.value / "src" / "main" / "scala",
    ),

    Compile / unmanagedSources := {
      val dirs = (Compile / unmanagedSourceDirectories).value
      val allSources = dirs.flatMap(dir => (dir ** "*.scala").get)
      val selected = sys.env
        .get("UCIE_ELAB_SOURCES")
        .map(_.split(":").toSeq.filter(_.nonEmpty))
        .getOrElse(Seq.empty)

      def pathOf(file: File): String = file.getPath.replace('\\', '/')
      def isGeneratedRunner(file: File): Boolean =
        pathOf(file).contains("/elab/src/main/scala/")
      def isCommonDependency(file: File): Boolean = {
        val path = pathOf(file)
        path.contains("/scala/src/interfaces/") ||
        path.contains("/scala/src/logphy/utils/") ||
        path.contains("/scala/src/sideband/utils/") ||
        path.contains("/scala/src/utils/")
      }
      def isSelected(file: File): Boolean = {
        val path = pathOf(file)
        selected.exists { sel =>
          val s = sel.replace('\\', '/')
          if (s.endsWith("/")) {
            val prefix = s.stripSuffix("/")
            path.contains("/" + prefix + "/") || path.endsWith("/" + prefix)
          } else {
            path.endsWith(s)
          }
        }
      }

      if (selected.nonEmpty)
        allSources.filter(file =>
          isGeneratedRunner(file) || isCommonDependency(file) || isSelected(file)
        )
      else
        allSources.filter(file =>
          !pathOf(file).contains("/tilelink/") &&
          !pathOf(file).contains("/phy/") &&
          !pathOf(file).contains("/logphy/elab/") &&
          file.getName != "SidebandLinkSerdes.scala"
        )
    },
  )
