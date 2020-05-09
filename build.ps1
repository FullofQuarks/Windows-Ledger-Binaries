cd boost
git pull
.\bootstrap.bat
.\b2.exe link=static runtime-link=static threading=multi --layout=versioned
cd ..\mpir\msvc\vs19
git pull
.\msbuild.bat gc LIB Win32 Release
cd ..\..\..\mpfr\build.vs19\lib_mpfr
git pull
msbuild /p:Configuration=Release lib_mpfr.vcxproj
cd ..\..\..\ledger
git pull
cmake -DCMAKE_BUILD_TYPE:STRING="Release" -DBUILD_LIBRARY=OFF -DMPFR_LIB:FILEPATH="../../mpfr/build.vs19/lib/Win32/Release/mpfr" -DGMP_LIB:FILEPATH="../../mpir/lib/win32/Release/mpir" -DMPFR_PATH:PATH="../mpfr/lib/Win32/Release" -DGMP_PATH:PATH="../mpir/lib/win32/Release" -DBUILD_DOCS:BOOL="0" -DHAVE_REALPATH:BOOL="0" -DHAVE_GETPWUID:BOOL="0" -DHAVE_GETPWNAM:BOOL="0" -DHAVE_IOCTL:BOOL="0" -DHAVE_ISATTY:BOOL="0" -DBOOST_ROOT:PATH="../boost/" -DBoost_USE_STATIC_LIBS:BOOL="1" -DCMAKE_CXX_FLAGS_RELEASE:STRING="/MT /Zi /Ob0 /Od" -A Win32 -G "Visual Studio 16"
msbuild /p:Configuration=Release src\ledger.vcxproj
copy Release\ledger.exe ..\