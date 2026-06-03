{
	description = "Snapmaker Orca Slicer — community-patched fork";

	inputs.nixpkgs.url = "github:ealap/nix-packages/331800de5053fcebacf6813adb5db9c9dca22a0c";

	outputs = {
		self,
		nixpkgs,
	}: let
		pname = "snapmaker-orca";
		version = "12.3.3";
		system = "x86_64-linux";
		pkgs = nixpkgs.legacyPackages.${system};
	in {
		packages.${system} = let
			drv = pkgs.orca-slicer.overrideAttrs (oldAttrs: {
					inherit pname version;

					src = self;

					buildInputs = oldAttrs.buildInputs ++ [
						pkgs.libnoise
					];

					# nixpkgs libnoise installs lib/libnoise-static.a and include/noise/;
					# the custom Findlibnoise.cmake looks for different NAMES and libnoise/noise.h,
					# so override the cmake cache variables directly to bypass the finder.
					cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
						"-DLIBNOISE_LIBRARY=${pkgs.libnoise}/lib/libnoise-static.a"
						"-DLIBNOISE_INCLUDE_DIR=${pkgs.libnoise}/include"
					];

					# Drop fetchpatch entries (OrcaSlicer-specific update-check PR);
					# keep local path patches (WebKit linking, OpenCV, no-ilmbase).
					patches = builtins.filter (p: !(builtins.isAttrs p)) oldAttrs.patches;

					# paho-mqtt-c CMake + C23 compat fixes applied in-place:
					# - cmake_minimum_required < 3.5 removed in CMake 4.x
					# - C23 makes bool a keyword (not a macro); guard on __STDC_VERSION__
					# nixpkgs libnoise uses include/noise/ but source includes "libnoise/noise.h";
					# fix the one include site to match the installed path.
					prePatch =
						(oldAttrs.prePatch or "")
						+ ''
							sed -i 's/cmake_minimum_required *( *VERSION [0-9][^)]*)/cmake_minimum_required(VERSION 3.5)/I' \
								src/mqtt/externals/paho-mqtt-c/CMakeLists.txt
							sed -i 's/typedef unsigned int bool;/#if !(__STDC_VERSION__ >= 202311L)\ntypedef unsigned int bool;\n#endif/' \
								src/mqtt/externals/paho-mqtt-c/src/MQTTPacket.h
							sed -i 's|#include "libnoise/noise\.h"|#include "noise/noise.h"|' \
								src/libslic3r/Feature/FuzzySkin/FuzzySkin.cpp
						'';

					doCheck = false;

					# Icon=Snapmaker_Orca requires an icon-theme cache lookup that HM packages
					# don't trigger. Rewrite to an absolute store path so any launcher finds it.
					postInstall =
						(oldAttrs.postInstall or "")
						+ ''
							sed -i "s|Icon=Snapmaker_Orca|Icon=$out/share/icons/hicolor/192x192/apps/Snapmaker_Orca.png|" \
								$out/share/applications/Snapmaker_Orca.desktop
						'';

					meta =
						oldAttrs.meta
						// {
							description = "Slicing software for Snapmaker 3D printers";
							homepage = "https://www.snapmaker.com/snapmaker-orca";
							changelog = "https://github.com/ealap/SnapmakerOrca/tree/snapmaker/community-patches";
							mainProgram = pname;
							maintainers = [];
						};
				});
		in {
			default = drv;
			${pname} = drv;
		};
	};
}
