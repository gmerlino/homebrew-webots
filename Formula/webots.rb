class Webots < Formula
  desc "Robot simulator with native controllers and a graphical world editor"
  homepage "https://cyberbotics.com/"
  url "https://github.com/cyberbotics/webots.git", tag: "R2025a", revision: "c6793d8f7230a311c4bc2a3101d9f1a8bc0aa01b"
  version "2025a"
  license "Apache-2.0"
  revision 1

  depends_on "swig" => :build
  depends_on xcode: :build
  depends_on arch: :arm64
  depends_on "assimp"
  depends_on "ffmpeg"
  depends_on "freetype"
  depends_on "libssh"
  depends_on :macos
  depends_on "openjdk"
  depends_on "openssl@4"
  depends_on "python@3.14"
  depends_on "qtbase"
  depends_on "qtdeclarative"
  depends_on "qttools"
  depends_on "qtwebsockets"

  # Preserve upstream joystick and speech support, using their official macOS libraries.
  resource "ois" do
    url "https://cyberbotics.com/files/repository/dependencies/mac/release/libOIS-1.3.tar.bz2"
    sha256 "fed801d07e903474056bd7f371f40aa96a60a1b3e4fb4538d85f362cd08e75b4"
  end

  resource "pico" do
    url "https://cyberbotics.com/files/repository/dependencies/mac/release/libpico-1.0.tar.bz2"
    sha256 "bed1465d96d609c57eb652774a62f33e5f545cead85a833dd90af996bd579fc1"
  end

  resource "robotis-zip" do
    url "https://cyberbotics.com/files/repository/dependencies/mac/release/libzip.tar.bz2"
    sha256 "ae99c5d7c3916fba9a9fe77c3f728f93430140aafab38b3c59119e10de526508"
  end

  resource "xc16" do
    url "https://www.cyberbotics.com/files/repository/dependencies/mac/release/xc16-1.24.zip"
    sha256 "ac69a69bd0c5f8cb04d0da6c9d2bc4b0da879b9954f00ee1e5b57ca582b3084b"
  end

  patch :DATA

  def install
    ENV["WEBOTS_HOME"] = buildpath
    ENV["JAVA_HOME"] = formula_opt_prefix("openjdk")/"libexec/openjdk.jdk/Contents/Home"
    ENV.prepend_path "PATH", formula_opt_bin("openjdk")
    ENV["NO_FAT_BINARY"] = "1"
    ENV["PROCESSOR"] = "arm64"
    %w[ois pico].each do |name|
      resource(name).stage { cp_r Dir["*"], buildpath }
    end
    %w[zip].each do |name|
      cp resource("robotis-#{name}").cached_download, buildpath/"dependencies/lib#{name}.tar.bz2"
    end
    resource("xc16").stage(buildpath/"projects/robots/gctronic/e-puck/transfer/xc16")
    %w[qtbase qtdeclarative qtwebsockets].each do |name|
      (buildpath/"Contents/Frameworks").install_symlink Dir[formula_opt_prefix(name)/"lib/*.framework"]
    end
    (buildpath/"bin/qt").install_symlink formula_opt_prefix("qtbase")/"share/qt/libexec/moc"
    %w[lrelease lupdate].each do |name|
      (buildpath/"bin/qt").install_symlink formula_opt_bin("qttools")/name
    end
    %w[resources include projects docs].each do |name|
      target = if name == "resources"
        "Resources"
      else
        name
      end
      (buildpath/"Contents"/target).make_symlink "../#{name}"
    end
    %w[matlab python].each do |name|
      (buildpath/"Contents/lib/controller").mkpath
      (buildpath/"Contents/lib/controller"/name).make_symlink "../../../lib/controller/#{name}"
    end
    %w[OIS pico].each do |name|
      library = "lib#{name}.dylib"
      (buildpath/"Contents/lib/webots").install buildpath/"lib/webots"/library
      (buildpath/"Contents/lib/webots"/library).change_dylib_id "@rpath/Contents/lib/webots/#{library}"
      system "codesign", "--force", "--sign", "-", buildpath/"Contents/lib/webots"/library
    end
    (buildpath/"Contents/lib/webots").install_symlink formula_opt_prefix("assimp")/"lib/libassimp.dylib"
    (buildpath/"Contents/util").install_symlink formula_opt_bin("ffmpeg")/"ffmpeg"
    (buildpath/"dependencies/freetype2").make_symlink formula_opt_prefix("freetype")/"include/freetype2"
    (buildpath/"dependencies/assimp").mkpath
    (buildpath/"dependencies/assimp/include").make_symlink formula_opt_prefix("assimp")/"include"
    (buildpath/"Contents/lib/webots/qt").mkpath
    (buildpath/"Contents/lib/webots/qt/plugins").make_symlink formula_opt_prefix("qtbase")/"share/qt/plugins"
    inreplace "projects/robots/robotis/darwin-op/libraries/Makefile.mac", "PACKAGES = ssh zip", "PACKAGES = zip"
    ssh = buildpath/"projects/robots/robotis/darwin-op/libraries/libssh"
    ssh.mkpath
    cp (formula_opt_prefix("libssh")/"lib/libssh.4.dylib").realpath, ssh/"libssh.4.dylib"
    (ssh/"libssh.dylib").make_symlink "libssh.4.dylib"
    (ssh/"include").mkpath
    cp_r formula_opt_prefix("libssh")/"include/libssh", ssh/"include"
    system "make", "release"
    app = prefix/"Webots.app"
    app.mkpath
    app.install buildpath/"Contents"
    %w[resources include projects docs].each do |name|
      target = if name == "resources"
        "Resources"
      else
        name
      end
      (app/"Contents"/target).unlink
      (app/"Contents").install buildpath/name => target
    end
    %w[python matlab].each do |name|
      (app/"Contents/lib/controller"/name).unlink
      (app/"Contents/lib/controller").install buildpath/"lib/controller"/name
    end
    (app/"Contents").install buildpath/"bin", buildpath/"scripts"
    (app/"Contents/Resources").install buildpath/"LICENSE"
    (app/"Contents/src").install buildpath/"src/controller"
    Dir[app/"Contents/src/controller/**/build"].each { |path| rm_r path }
    Dir[app/"Contents/projects/**/build"].each { |path| rm_r path }
    (app/"Contents/Resources/qt.conf").unlink
    (app/"Contents/Resources/qt.conf").write <<~CONF
      [Paths]
      Plugins = #{formula_opt_prefix("qtbase")}/share/qt/plugins
      QmlImports = #{formula_opt_prefix("qtdeclarative")}/share/qt/qml
    CONF
    (app/"Contents/.gitignore").unlink
    Dir[app/"Contents/Frameworks/*.framework"].each { |path| Pathname(path).unlink }
    %w[lib/webots/libassimp.dylib lib/webots/qt/plugins].each do |name|
      (app/"Contents"/name).unlink
    end
    %w[util/ffmpeg bin/qt/moc bin/qt/lrelease bin/qt/lupdate].each do |name|
      path = app/"Contents"/name
      target = path.readlink
      path.unlink
      path.write <<~SH
        #!/bin/sh
        exec "#{target}" "$@"
      SH
      path.chmod 0755
    end
    Dir[app/"Contents/**/Makefile"].each do |path|
      next unless File.read(path).include?("$(WEBOTS_HOME)/Contents/Frameworks")

      inreplace path, "$(WEBOTS_HOME)/Contents/Frameworks", (formula_opt_prefix("qtbase")/"lib").to_s
    end
    (bin/"webots").write <<~SH
      #!/bin/sh
      exec "#{opt_prefix}/Webots.app/Contents/MacOS/webots" "$@"
    SH
  end

  post_install_steps do
    run "/usr/bin/codesign",
        args:           ["--force", "--sign", "-",
                         "{{prefix}}/Webots.app/Contents/Resources/projects/plugins/" \
                         "robot_windows/generic/libgeneric.dylib"],
        writable_paths: ["{{prefix}}/Webots.app"]
    run "/usr/bin/codesign", args:           ["--force", "--sign", "-", "{{prefix}}/Webots.app"],
                             writable_paths: ["{{prefix}}/Webots.app"]
  end

  def caveats
    <<~EOS
      GUI: #{opt_prefix}/Webots.app
      Controller development:
        export WEBOTS_HOME=#{opt_prefix}/Webots.app
        export WEBOTS_HOME_PATH="$WEBOTS_HOME/Contents"
      Built from R2025a with Homebrew Qt 6. Upstream OIS and Pico binaries are retained.
    EOS
  end

  test do
    ENV["QT_QPA_PLATFORM"] = "offscreen"
    assert_match "R2025a", shell_output("#{bin}/webots --version")
    app = prefix/"Webots.app"
    assert_path_exists app/"Contents/lib/controller/java/Controller.jar"
    (testpath/"check.py").write <<~PYTHON
      import ctypes
      library = ctypes.CDLL("#{app}/Contents/lib/controller/libController.dylib")
      assert library.wb_robot_init
      assert library.wb_robot_step
      assert library.wb_supervisor_node_get_from_def
    PYTHON
    system formula_opt_bin("python@3.14")/"python3.14", testpath/"check.py"
    (testpath/"main.cpp").write <<~CPP
      #include <webots/Supervisor.hpp>
      int main() { webots::Supervisor robot; return robot.step(32); }
    CPP
    system ENV.cxx, "main.cpp", "-I#{app}/Contents/include/controller/cpp",
           "-L#{app}/Contents/lib/controller", "-lCppController", "-lController", "-o", "controller-test"
    assert_path_exists testpath/"controller-test"
  end
end

__END__
diff --git a/Makefile b/Makefile
index 2c7d33b..12669d5 100644
--- a/Makefile
+++ b/Makefile
@@ -92,7 +92,7 @@ ifeq ($(OSTYPE),windows)
 	@rm -rf msys64
 endif
 ifeq ($(OSTYPE),darwin)
-	@+make --silent -C dependencies -f Makefile.mac $(MAKECMDGOALS)
+	@true
 endif
 	@+echo "#"; echo "# * tests *"; echo "#"
 	@find tests -name .*.cache | xargs rm -f
@@ -125,7 +125,7 @@ webots_projects: webots_target
 webots_dependencies:
 	@+echo "#"; echo "# * dependencies *"; echo "#"
 ifeq ($(OSTYPE),darwin)
-	@+make --silent -C dependencies -f Makefile.mac $(MAKECMDGOALS)
+	@true
 endif
 ifeq ($(OSTYPE),linux)
 	@+make --silent -C dependencies -f Makefile.linux $(MAKECMDGOALS)
diff --git a/projects/default/libraries/vehicle/java/Makefile b/projects/default/libraries/vehicle/java/Makefile
index 9db52e6..9d73225 100644
--- a/projects/default/libraries/vehicle/java/Makefile
+++ b/projects/default/libraries/vehicle/java/Makefile
@@ -101,11 +101,10 @@ $(WRAPPER_OBJECT_X86_64): $(WRAPPER)
 	@mkdir -p $(WEBOTS_CONTROLLER_LIB_PATH)/java
 	@$(CXX) -shared -mwindows -Wl,--add-stdcall-alias -Wl,--enable-auto-import -O -lm $< $(LIB) -o "$@"
 
-%.jnilib: $(WRAPPER_OBJECT_ARM64) $(WRAPPER_OBJECT_X86_64)
+%.jnilib: $(WRAPPER_OBJECT_ARM64)
 	@$(CXX) -target arm64-apple-macos12 $(CFLAGS1) -bundle $(WRAPPER_OBJECT_ARM64) $(LIB) -o lib$(MODULE_NAME)-arm64.jnilib
-	@$(CXX) -target x86_64-apple-macos12 $(CFLAGS1) -bundle $(WRAPPER_OBJECT_X86_64) $(LIB) -o lib$(MODULE_NAME)-x86_64.jnilib
 	@mkdir -p $(WEBOTS_CONTROLLER_LIB_PATH)/java
-	@lipo -create -output "$@" lib$(MODULE_NAME)-arm64.jnilib lib$(MODULE_NAME)-x86_64.jnilib
+	@cp lib$(MODULE_NAME)-arm64.jnilib "$@"
 	@codesign -s - "$@"
 endif
 
diff --git a/projects/robots/gctronic/e-puck/plugins/robot_windows/botstudio/Makefile b/projects/robots/gctronic/e-puck/plugins/robot_windows/botstudio/Makefile
index a28c6c4..90836b1 100644
--- a/projects/robots/gctronic/e-puck/plugins/robot_windows/botstudio/Makefile
+++ b/projects/robots/gctronic/e-puck/plugins/robot_windows/botstudio/Makefile
@@ -115,6 +115,7 @@ ifeq ($(OSTYPE),darwin)
  MOC = "$(WEBOTS_HOME)/bin/qt/moc"
  MOC_PLATFORM_FLAGS = -D__APPLE__
  FRAMEWORKS += -framework QtCore -framework QtGui -framework QtWidgets -framework QtConcurrent
+ OBJECTS += $(addprefix $(BUILD_GOAL_DIR)/,$(notdir $(MOC_SOURCES:.cpp=.o)))
  X86_64_OBJECTS += $(addprefix $(BUILD_GOAL_DIR)/x86_64/,$(notdir $(MOC_SOURCES:.cpp=.o)))
  ARM64_OBJECTS += $(addprefix $(BUILD_GOAL_DIR)/arm64/,$(notdir $(MOC_SOURCES:.cpp=.o)))
 endif
@@ -129,7 +130,7 @@ $(BUILD_DIR)/%.moc.cpp: %.hpp
 	$(SILENT)$(MOC) $(MOC_PLATFORM_FLAGS) $(INCLUDE:-isystem:-I) $< -o $@
 
 ifeq ($(OSTYPE),darwin)
-$(BUILD_GOAL_DIR)/$(MAIN_TARGET): $(BUILD_GOAL_DIR)/x86_64/$(MAIN_TARGET) $(BUILD_GOAL_DIR)/arm64/$(MAIN_TARGET)
+$(BUILD_GOAL_DIR)/$(MAIN_TARGET): $(OBJECTS)
 $(BUILD_GOAL_DIR)/x86_64/$(MAIN_TARGET): $(X86_64_OBJECTS)
 $(BUILD_GOAL_DIR)/arm64/$(MAIN_TARGET): $(ARM64_OBJECTS)
 else
diff --git a/projects/vehicles/plugins/robot_windows/automobile_window/Makefile b/projects/vehicles/plugins/robot_windows/automobile_window/Makefile
index 3e4e26b..9639626 100644
--- a/projects/vehicles/plugins/robot_windows/automobile_window/Makefile
+++ b/projects/vehicles/plugins/robot_windows/automobile_window/Makefile
@@ -27,7 +27,7 @@ HPP_FILES_TO_MOC = GeneralInformationWidget.hpp AbstractWidget.hpp
 USE_C_API = true
 
 NO_FAT_BINARY = 1
-PROCESSOR = x86_64
+PROCESSOR = arm64
 QT_UTILS = $(WEBOTS_HOME)/resources/projects/libraries/qt_utils
 INCLUDE = -I"$(QT_UTILS)"
 LIBRARIES = -L"$(QT_UTILS)" -lqt_utils -ldriver -lcar
diff --git a/resources/Makefile.include b/resources/Makefile.include
index 461793b..368b891 100644
--- a/resources/Makefile.include
+++ b/resources/Makefile.include
@@ -119,6 +119,8 @@ ifeq ($(OSTYPE),darwin)
    fi; \
  )
 
+NO_FAT_BINARY ?= 1
+PROCESSOR ?= arm64
 ifndef NO_FAT_BINARY
 FAT_BINARY = 1
 endif
diff --git a/resources/projects/libraries/qt_utils/Makefile b/resources/projects/libraries/qt_utils/Makefile
index 79c5576..babae3f 100644
--- a/resources/projects/libraries/qt_utils/Makefile
+++ b/resources/projects/libraries/qt_utils/Makefile
@@ -133,6 +133,7 @@ ifeq ($(OSTYPE),darwin)
  MOC = "$(WEBOTS_HOME)/bin/qt/moc"
  MOC_PLATFORM_FLAGS = -D__APPLE__
  FRAMEWORKS += -framework QtCore -framework QtGui -framework QtWidgets
+ OBJECTS += $(addprefix $(BUILD_GOAL_DIR)/,$(notdir $(MOC_SOURCES:.cpp=.o)))
  X86_64_OBJECTS += $(addprefix $(BUILD_GOAL_DIR)/x86_64/,$(notdir $(MOC_SOURCES:.cpp=.o)))
  ARM64_OBJECTS += $(addprefix $(BUILD_GOAL_DIR)/arm64/,$(notdir $(MOC_SOURCES:.cpp=.o)))
 endif
diff --git a/src/controller/c/Makefile b/src/controller/c/Makefile
index 14a32c7..64b8385 100644
--- a/src/controller/c/Makefile
+++ b/src/controller/c/Makefile
@@ -147,9 +147,9 @@ ifeq ($(OSTYPE),darwin)
 X86_64_OBJECTS = $(addprefix $(OBJDIR)/x86_64/, $(OBJECTS))
 ARM64_OBJECTS = $(addprefix $(OBJDIR)/arm64/, $(OBJECTS))
 
-$(TARGET): $(OBJDIR)/x86_64/libController.dylib $(OBJDIR)/arm64/libController.dylib
+$(TARGET): $(OBJDIR)/arm64/libController.dylib
 	@echo "# creating fat binary: $$"\(WEBOTS_HOME\)/lib/controller/libController.dylib
-	@lipo -create -output $(TARGET) $(OBJDIR)/x86_64/libController.dylib $(OBJDIR)/arm64/libController.dylib
+	@cp $(OBJDIR)/arm64/libController.dylib $(TARGET)
 	@chmod a-x $@
 	@codesign -s - $@
 
@@ -195,3 +195,5 @@ $(OBJDIR)/%.d:%.c
 FILES_TO_REMOVE = $(TARGET)
 FILES_TO_REMOVE += $(WEBOTS_CONTROLLER_LIB_PATH)/libController.a
 FILES_TO_REMOVE += $(WEBOTS_CONTROLLER_LIB_PATH)/libController.lib
+
+BUILD_NATIVE_DIRS := $(shell mkdir -p build/release/arm64 build/debug/arm64)
diff --git a/src/controller/cpp/Makefile b/src/controller/cpp/Makefile
index dde0a6e..57b2b1e 100644
--- a/src/controller/cpp/Makefile
+++ b/src/controller/cpp/Makefile
@@ -124,9 +124,9 @@ ifeq ($(OSTYPE),darwin)
 X86_64_OBJECTS = $(addprefix $(BUILD_GOAL_DIR)/x86_64/,$(OBJECTS))
 ARM64_OBJECTS = $(addprefix $(BUILD_GOAL_DIR)/arm64/,$(OBJECTS))
 
-$(TARGET): $(BUILD_GOAL_DIR)/x86_64/libCppController.dylib $(BUILD_GOAL_DIR)/arm64/libCppController.dylib
+$(TARGET): $(BUILD_GOAL_DIR)/arm64/libCppController.dylib
 	@echo "# creating fat" $(notdir $@)
-	@lipo -create -output $@ $(BUILD_GOAL_DIR)/x86_64/libCppController.dylib $(BUILD_GOAL_DIR)/arm64/libCppController.dylib
+	@cp $(BUILD_GOAL_DIR)/arm64/libCppController.dylib $@
 	@codesign -s - $@
 
 $(BUILD_GOAL_DIR)/x86_64/libCppController.dylib: $(X86_64_OBJECTS)
@@ -173,3 +173,5 @@ else
 FILES_TO_REMOVE = $(WEBOTS_CONTROLLER_LIB_PATH)/*Cpp*
 endif
 FILES_TO_REMOVE += $(CPPOBJS) $(DEPENDENCIES)
+
+BUILD_NATIVE_DIRS := $(shell mkdir -p build/release/arm64 build/debug/arm64)
diff --git a/src/controller/java/Makefile b/src/controller/java/Makefile
index 5d362d7..4f0cccb 100644
--- a/src/controller/java/Makefile
+++ b/src/controller/java/Makefile
@@ -162,10 +162,10 @@ $(OBJDIR)/x86_64/lib$(LIBNAME).jnilib: $(WRAPPER_OBJECT_X86_64)
 	@echo "# linking" $(notdir $^) "(x86_64)"
 	$(CXX) -target x86_64-apple-macos12 $(CFLAGS1) $(JNILIB_FLAGS) -L$(WEBOTS_CONTROLLER_LIB_PATH) -lController -lCppController $^ -o "$@"
 
-$(WEBOTS_CONTROLLER_LIB_PATH)/java/lib$(LIBNAME).jnilib: $(OBJDIR)/arm64/lib$(LIBNAME).jnilib $(OBJDIR)/x86_64/lib$(LIBNAME).jnilib
+$(WEBOTS_CONTROLLER_LIB_PATH)/java/lib$(LIBNAME).jnilib: $(OBJDIR)/arm64/lib$(LIBNAME).jnilib
 	@echo "# creating fat" $^
 	@mkdir -p $(WEBOTS_CONTROLLER_LIB_PATH)/java
-	lipo -create -output "$@" $(OBJDIR)/x86_64/lib$(LIBNAME).jnilib $(OBJDIR)/arm64/lib$(LIBNAME).jnilib
+	cp $(OBJDIR)/arm64/lib$(LIBNAME).jnilib "$@"
 	codesign -s - "$@"
 
 $(WEBOTS_CONTROLLER_LIB_PATH)/java/lib$(LIBNAME).so: $(WRAPPER_OBJECT)
@@ -205,3 +205,5 @@ FILES_TO_REMOVE = $(SWIG_OUTPUT_PATH)
 endif
 FILES_TO_REMOVE += $(TARGET) $(JAR_FILE) *.o com
 EMPTY_DIRECTORIES_TO_REMOVE = $(WEBOTS_CONTROLLER_LIB_PATH)/java
+
+BUILD_NATIVE_DIRS := $(shell mkdir -p build/release/arm64 build/debug/arm64)
diff --git a/src/webots/Makefile b/src/webots/Makefile
index 945f945..0ce8136 100644
--- a/src/webots/Makefile
+++ b/src/webots/Makefile
@@ -83,12 +83,12 @@ QT_WEBSOCKETS_INCLUDE = -isystem $(FRAMEWORKS)/QtWebSockets.framework/Headers
 QT_XML_INCLUDE     = -isystem $(FRAMEWORKS)/QtXml.framework/Headers
 FREETYPE_INCLUDE   = -isystem $(WEBOTS_DEPENDENCY_PATH)/freetype2
 ASSIMP_INCLUDE     = -I$(WEBOTS_DEPENDENCY_PATH)/assimp/include
-LD_FLAGS           = -mmacosx-version-min=$(MACOSX_MIN_SDK_VERSION) -L$(WEBOTS_LIB_PATH) -lOIS -lpico -lassimp -Xlinker -rpath -Xlinker @loader_path/../..
+LD_FLAGS           = -mmacosx-version-min=$(MACOSX_MIN_SDK_VERSION) -L$(WEBOTS_LIB_PATH) -lOIS -lpico -lassimp -L/opt/homebrew/opt/freetype/lib -lfreetype -Xlinker -rpath -Xlinker @loader_path/../..
 MOC                =  $(WEBOTS_PATH)/bin/qt/moc
 LIBS_FRAMEWORKS    = -F$(FRAMEWORKS) -framework OpenAL -framework OpenGL -framework QtCore -framework QtGui -framework QtPrintSupport -framework QtQml -framework QtNetwork -framework QtOpenGL -framework QtOpenGLWidgets -framework QtWebSockets -framework QtWidgets -framework QtXml -framework IOKit -framework CoreFoundation -framework Cocoa
 LIBS              += -bind_at_load $(LIBS_FRAMEWORKS) $(LIB_WREN)
 CFLAGS             = -isysroot $(MACOSX_SDK_PATH) -mmacosx-version-min=$(MACOSX_MIN_SDK_VERSION)
-CXXFLAGS           = -std=c++11 -F$(FRAMEWORKS) -x objective-c++
+CXXFLAGS           = -std=c++17 -F$(FRAMEWORKS) -x objective-c++
 EXTRA_CMD          = cp launcher/webots-mac.sh $(WEBOTS_PATH)/webots && chmod 755 $(WEBOTS_PATH)/webots
 FILES_TO_REMOVE    = $(WEBOTS_PATH)/webots
 ifeq ($(MAKECMDGOALS), profile)
@@ -117,7 +117,7 @@ QT_XML_INCLUDE     = -isystem $(WEBOTS_PATH)/include/qt/QtXml
 FREETYPE_INCLUDE   = -I/usr/include/freetype2
 TARGET             = $(WEBOTS_PATH)/bin/webots-bin
 CFLAGS             = -fPIC
-CXXFLAGS           = -std=c++11
+CXXFLAGS           = -std=c++17
 MOC                = $(WEBOTS_PATH)/bin/qt/moc
 LIBS              += $(LIB_WREN) -Wl,-rpath $(WEBOTS_LIB_PATH) -L$(WEBOTS_LIB_PATH) -lQt6Core -lQt6Network -lQt6Gui -lQt6OpenGL -lQt6OpenGLWidgets -lQt6WebSockets -lQt6Widgets -lQt6PrintSupport -lQt6Qml -lQt6Xml -lopenal -lGL -lGLU -ldl -lOIS -lpico -lfreetype -lassimp -lrt
 LD_FLAGS           = -rdynamic
@@ -150,7 +150,7 @@ FREETYPE_INCLUDE          = -I/mingw64/include/freetype2
 TARGET_PATH               = $(WEBOTS_PATH)/msys64/mingw64/bin
 TARGET                    = $(TARGET_PATH)/webots-bin.exe
 CFLAGS                    = -isystem /mingw64/lib/libzip/include
-CXXFLAGS                  = -std=c++11 -D_USE_MATH_DEFINES
+CXXFLAGS                  = -std=c++17 -D_USE_MATH_DEFINES
 MOC                       = /mingw64/share/qt6/bin/moc
 MOC_FLAGS                += -D_WIN32
 LIBS                     += $(LIB_WREN) -L$(TARGET_PATH) -L/mingw64/bin -L/mingw64/lib -lQt6Core -lQt6Network -lQt6Gui -lQt6OpenGL -lQt6OpenGLWidgets -lQt6WebSockets -lQt6Widgets -lQt6PrintSupport -lQt6Qml -lQt6Xml -lode -lopenal -lopengl32 -liphlpapi -ld3d9 -lgdi32 -lglu32 -lOIS -ldinput8 -ldxguid -lole32 -lsapi -loleaut32 -luuid -lpico -lfreetype-6 -lopenvr_api -lassimp-5
@@ -632,9 +632,9 @@ ifeq ($(OSTYPE),darwin)
 X86_64_OBJECTS = $(addprefix $(OBJDIR)/x86_64/, $(OBJECTS))
 ARM64_OBJECTS = $(addprefix $(OBJDIR)/arm64/, $(OBJECTS))
 
-$(TARGET): $(OBJDIR)/x86_64/webots $(OBJDIR)/arm64/webots
+$(TARGET): $(OBJDIR)/arm64/webots
 	@echo "# creating fat " $@
-	@lipo -create -output webots $(OBJDIR)/x86_64/webots $(OBJDIR)/arm64/webots
+	@cp $(OBJDIR)/arm64/webots webots
 	@codesign -s - webots
 	@mv webots $(TARGET)
 	@$(EXTRA_CMD)
@@ -672,7 +672,7 @@ $(OBJDIR)/x86_64/%.moc.cpp: %.hpp
 
 $(OBJDIR)/arm64/%.moc.cpp: %.hpp
 	@echo "# moc-generating" $@ "(arm64)"
-	@$(MOC) -target arm64-apple-macos-11 $(MOC_FLAGS) $(INCLUDE:-isystem:-I) $< -o $@
+	@$(MOC)  $(MOC_FLAGS) $(INCLUDE:-isystem:-I) $< -o $@
 
 launcher/launcher.o: launcher/launcher.rc
 	@windres -i $< -o $@ --define _WIN32 --define __WIN32__ --define __WIN95__ --define __GNUWIN32__
diff --git a/src/webots/gui/WbTcpServer.cpp b/src/webots/gui/WbTcpServer.cpp
index 9647f2a..c0e9f3b 100644
--- a/src/webots/gui/WbTcpServer.cpp
+++ b/src/webots/gui/WbTcpServer.cpp
@@ -13,6 +13,11 @@
 // limitations under the License.
 
 #include "WbTcpServer.hpp"
+#ifdef __APPLE__
+#include <sys/socket.h>
+#include <netinet/in.h>
+#include <unistd.h>
+#endif
 
 #include "WbApplication.hpp"
 #include "WbControlledWorld.hpp"
@@ -135,12 +140,39 @@ void WbTcpServer::create(int port) {
   // and Qt does not provide a way to configure the socket before calling listen() [2].
   // [1] https://doc.qt.io/qt-6/qabstractsocket.html#BindFlag-enum
   // [2] https://stackoverflow.com/questions/47268023/how-to-set-so-reuseaddr-on-the-socket-used-by-qtcpserver
+#ifdef __APPLE__
+  // Some Qt versions report a successful connection without a valid peer.
+  // Probe both loopback families with native sockets before opening the server.
+  bool occupied = false;
+  for (int family : {AF_INET, AF_INET6}) {
+    const int fd = ::socket(family, SOCK_STREAM, 0);
+    if (fd < 0)
+      continue;
+    if (family == AF_INET) {
+      sockaddr_in address = {};
+      address.sin_family = AF_INET;
+      address.sin_port = htons(port);
+      address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
+      occupied |= ::connect(fd, reinterpret_cast<sockaddr *>(&address), sizeof(address)) == 0;
+    } else {
+      sockaddr_in6 address = {};
+      address.sin6_family = AF_INET6;
+      address.sin6_port = htons(port);
+      address.sin6_addr = in6addr_loopback;
+      occupied |= ::connect(fd, reinterpret_cast<sockaddr *>(&address), sizeof(address)) == 0;
+    }
+    ::close(fd);
+  }
+  if (occupied)
+    throw tr("Port %1 is already in use").arg(port);
+#else
   QTcpSocket socket;
   socket.connectToHost("localhost", port);
   if (socket.waitForConnected(100)) {
     socket.disconnectFromHost();
     throw tr("Port %1 is already in use").arg(port);
   }
+#endif
 
   // Reference to let live QTcpSocket and QWebSocketServer on the same port using `QWebSocketServer::handleConnection()`:
   // - https://bugreports.qt.io/browse/QTBUG-54276
diff --git a/src/wren/Makefile b/src/wren/Makefile
index 4daa8b8..4ba652c 100644
--- a/src/wren/Makefile
+++ b/src/wren/Makefile
@@ -22,7 +22,7 @@ include $(WEBOTS_HOME_PATH)/resources/Makefile.os.include
 WEBOTS_DEPENDENCY_PATH ?= $(WEBOTS_HOME_PATH)/dependencies
 
 STATIC_LIBRARY = true
-CFLAGS = -std=c++11 -DGLM_ENABLE_EXPERIMENTAL
+CFLAGS = -std=c++17 -DGLM_ENABLE_EXPERIMENTAL
 INCLUDE = -I$(WEBOTS_HOME_PATH)/include -I$(WEBOTS_HOME_PATH)/include/glad -I../glm -I../webots/external/siphash/
 VERBOSE = 1
 

--- a/src/webots/vrml/WbUrl.cpp
+++ b/src/webots/vrml/WbUrl.cpp
@@ -31,6 +31,23 @@
 #include <QtCore/QRegularExpression>
 #include <QtCore/QUrl>
 
+// Keep repository-style asset URLs portable across the macOS bundle layout.
+static QString localAssetPath(QString url) {
+  if (url.startsWith("webots://projects/"))
+    return url.replace(0, 18, WbStandardPaths::projectsPath());
+  if (url.startsWith("webots://resources/"))
+    return url.replace(0, 19, WbStandardPaths::resourcesPath());
+  return url.replace("webots://", WbStandardPaths::webotsHomePath());
+}
+
+static QString portableAssetPath(QString url) {
+  if (url.startsWith(WbStandardPaths::projectsPath()))
+    return url.replace(0, WbStandardPaths::projectsPath().size(), "webots://projects/");
+  if (url.startsWith(WbStandardPaths::resourcesPath()))
+    return url.replace(0, WbStandardPaths::resourcesPath().size(), "webots://resources/");
+  return url.replace(WbStandardPaths::webotsHomePath(), "webots://");
+}
+
 namespace {
   static QString gWorldFileName;
 };
@@ -126,7 +143,7 @@
     return url;
 
   if (isLocalUrl(url))
-    return QDir::cleanPath(url.replace("webots://", WbStandardPaths::webotsHomePath()));
+    return QDir::cleanPath(localAssetPath(url));
 
   return QDir::cleanPath(url);
 }
@@ -209,13 +226,13 @@
 
 QString WbUrl::computeLocalAssetUrl(QString url, bool isW3d) {
   if (!isW3d)
-    return url.replace(WbStandardPaths::webotsHomePath(), "webots://");
+    return portableAssetPath(url);
 
   if (!WbApplicationInfo::repo().isEmpty() && !WbApplicationInfo::branch().isEmpty()) {
     // when streaming locally, build the URL from branch.txt in order to serve 'webots://' assets
     const QString prefix =
       "https://raw.githubusercontent.com/" + WbApplicationInfo::repo() + "/" + WbApplicationInfo::branch() + "/";
-    return url.replace("webots://", prefix).replace(WbStandardPaths::webotsHomePath(), prefix);
+    return portableAssetPath(url).replace("webots://", prefix);
   }
 
   // when streaming from a distribution or nightly build, use the actual url
@@ -275,7 +292,7 @@
   if (WbUrl::isLocalUrl(url)) {
     // URL fall-back mechanism: only trigger if the parent is a world file (.wbt), and the file (webots://) does not exist
     if (parentUrl.endsWith(".wbt", Qt::CaseInsensitive) &&
-        !QFileInfo(QDir::cleanPath(url.replace("webots://", WbStandardPaths::webotsHomePath()))).exists()) {
+        !QFileInfo(QDir::cleanPath(localAssetPath(url))).exists()) {
       WbLog::error(QObject::tr("URL '%1' changed by fallback mechanism. Ensure you are opening the correct world.").arg(url));
       return url.replace("webots://", WbUrl::remoteWebotsAssetPrefix());
     }
@@ -286,7 +303,7 @@
       return url.replace("webots://", prefix);
 
     if (parentUrl.isEmpty() || WbUrl::isLocalUrl(parentUrl) || QDir::isAbsolutePath(parentUrl))
-      return QDir::cleanPath(url.replace("webots://", WbStandardPaths::webotsHomePath()));
+      return QDir::cleanPath(localAssetPath(url));
 
     return QString();
   }
@@ -299,7 +316,7 @@
       // remove filename from parent url
       parentUrl = parentUrl.sliced(0, parentUrl.lastIndexOf("/") + 1);
       if (WbUrl::isLocalUrl(parentUrl))
-        parentUrl.replace("webots://", WbStandardPaths::webotsHomePath());
+        parentUrl = localAssetPath(parentUrl);
 
       if (WbUrl::isWeb(parentUrl))
         return QUrl(parentUrl).resolved(QUrl(url)).toString();
