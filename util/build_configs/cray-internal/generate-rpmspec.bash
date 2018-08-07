#!/bin/bash

# Generate an RPM spec file for Chapel Cray Module
# Writes to stdout

set -e
thisfile=$( basename "$0" )

cwd=$( cd $(dirname "$0" ) && pwd )
source $cwd/../functions.bash

# Accept command line parameters of the form NAME=Value. Or use environment variables.

while test $# -gt 0; do
    case $1 in ( *=* ) export "$1" ;; esac
    shift
done

# Cray-internal-specific shell variables

source $cwd/common.bash

# Generate the first part of the spec file with shell expansion

cat <<PART_1
%define name chapel-$pkg_version
%define real_name chapel
%define version $rpm_version
%define pkg_version $pkg_version
%define src_version $src_version
%define pkg_release $rpm_release
%define build_type $chpl_platform
%define _binary_payload w9.gzdio
PART_1

# Notes:
#
#   "Source: %{real_name}-%{src_version}.tar.gz" (below) is bogus.
#   There is no such file. We do not use the usual RPM %setup macro.
#   Instead, we provide a _builddir (RPM_BUILD_DIR) already
#   pre-populated, to save the time of tarring/un-tarring the big
#   compressed tar file.
#   Rpmbuild uses the given "Source:" filename only to infer the
#   "basename" of RPM_BUILD_DIR (e.g. chapel-1.17.1).

# Generate the rest of the spec file, without shell expansion

cat <<\PART_2

Summary: Chapel language compiler and libraries
Name:    %{name}
Version: %{version}
Release: %{pkg_release}
Prefix:  /opt
License: Copyright 2018, Cray Inc. All Rights Reserved.
Packager: Cray, Inc
Group:   Development/Languages/Other
Source:  %{real_name}-%{src_version}.tar.gz
AutoReqProv: no
Requires:   modulefile-utils_1
Requires:   set_default_2
Requires:   /usr/bin/env
Requires:   make
Requires:   perl
Requires:   python

%if %{!?buildroot:1}%{?buildroot:0}
%{error: Missing required command line parameter --buildroot RPM_BUILD_ROOT}
%{error: Make sure you also have --define "_topdir TOPDIR" (where RPM_BUILD_ROOT is a subdir)}
%{error: Highly recommended: --define "_tmppath TMPDIR" (where TMPDIR is a subdir of TOPDIR)}
%quit
%endif

%description
Chapel language compiler and libraries

%prep

cd $RPM_BUILD_DIR/%{real_name}-%{src_version}
chmod -Rf a+rX,u+w,g-w,o-w .

%build

%install

cd          %{_topdir}
mkdir -p                                                $RPM_BUILD_ROOT/%{prefix}/cray/admin-pe/set_default_files
cp -p       set_default_%{real_name}_%{pkg_version}     $RPM_BUILD_ROOT/%{prefix}/cray/admin-pe/set_default_files
mkdir -p                                                $RPM_BUILD_ROOT/%{prefix}/modulefiles/%{real_name}
rm -f                                                   $RPM_BUILD_ROOT/%{prefix}/modulefiles/%{real_name}/%{pkg_version}
cp -p       modulefile-%{pkg_version}                   $RPM_BUILD_ROOT/%{prefix}/modulefiles/%{real_name}/%{pkg_version}
mkdir -p                                                $RPM_BUILD_ROOT/%{prefix}/%{real_name}/%{pkg_version}/%{build_type}

cd          $RPM_BUILD_DIR/%{real_name}-%{src_version}
find . -mindepth 1 -maxdepth 1 -exec mv -f {}           $RPM_BUILD_ROOT/%{prefix}/%{real_name}/%{pkg_version}/%{build_type} \;
# Clean up *.o files
#rm -rf     $RPM_BUILD_ROOT/%{prefix}/%{real_name}/%{pkg_version}/*/*/gen
rm -rf      $RPM_BUILD_ROOT/%{prefix}/%{real_name}/%{pkg_version}/%{build_type}/*/compiler/*/gen
rm -rf      $RPM_BUILD_ROOT/%{prefix}/%{real_name}/%{pkg_version}/%{build_type}/*/runtime/*/gen

%clean
#rm -fr $RPM_BUILD_ROOT/

%post
cd $RPM_INSTALL_PREFIX/modulefiles/%{real_name}
if [ ${CRAY_INSTALL_DEFAULT:-0} -eq 1 ] 
then
/bin/rm -f .version
fi
if [ ! -f .version ]
then
cat > .version << EOF
#%Module
set ModulesVersion "%{pkg_version}"
EOF
fi
if [ -f $RPM_INSTALL_PREFIX/modulefiles/%{real_name}/.version ]
then
chmod 644 $RPM_INSTALL_PREFIX/modulefiles/%{real_name}/.version
fi
chmod 755 $RPM_INSTALL_PREFIX/cray/admin-pe/set_default_files/set_default_%{real_name}_%{pkg_version}

sed --in-place "s:\[BASE_INSTALL_DIR\]:$RPM_INSTALL_PREFIX:g" $RPM_INSTALL_PREFIX/modulefiles/%{real_name}/%{pkg_version}

%postun
if [ $1 == 1 ]
then
exit 0
fi
cd $RPM_INSTALL_PREFIX/modulefiles/%{real_name}
if [ -f .version ]
then
dotversion=`grep ModulesVersion .version | cut -f 2 -d'"'`
if [ "$dotversion" = "%{pkg_version}" ]
then
echo "Uninstalled version and .version file match = %{pkg_version}."
echo "Removing .version file."
/bin/rm .version
fi
fi

%files
%defattr(-,root,root)
%{prefix}/%{real_name}/%{pkg_version}
%{prefix}/modulefiles/%{real_name}/%{pkg_version}
%{prefix}/cray/admin-pe/set_default_files/set_default_%{real_name}_%{pkg_version}
PART_2
