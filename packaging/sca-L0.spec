#
# spec file template for package sca-L0
#
# Copyright (c) 2020 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

Name:           sca-L0
# Ignore next line; source service will set the version
Version:        0
# Ignore next line; build will set the release
Release:        0
Summary:	Level 0 Supportconfig Analysis Utility
License:	GPL-2.0
Group:		Tools
URL:		https://github.com/andavissuse/sca-L0
# Ignore next line; source service will create source archive
Source:		https://github.com/andavissuse/sca-L0-%{version}.tar.xz
Requires:	sca-datasets = %{version}
Requires:	sca-susedata = %{version}
Requires:	python3-numpy python3-pandas python3-scikit-learn
Requires:	tar
Requires:	util-linux
Requires:	bc
Obsoletes:	sca-datasets-suse
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%package -n sca-datasets
Summary:        Datasets for Supportconfig Analyzer

%package -n sca-susedata
Summary:        SUSE Product Data for Supportconfig Analyzer

%description -n sca-datasets
sca-datasets contains existing SUSE supportconfig data provided via vectorized datasets.

%description -n sca-susedata
sca-susedata contains support-relevant data (lifecycles, rpm versions, etc.) for SUSE products.

%description
sca-L0 contains Level 0 utilities for analyzing supportconfigs.

%prep
# Unpack scripts, datasets, and susedata
%setup -n sca-L0-%version

%build
sed -i "s/^SCA_HOME=.*/SCA_HOME=\"\/opt\/suse\/sca\"/" ./sca-L0.conf
sed -i "s/^VERSION=.*/VERSION=\"%{version}\"/" ./bin/sca-L0.sh

%install
# sca-L0
mkdir -p %{buildroot}/etc
mkdir -p %{buildroot}/opt/suse/sca/bin
install -c -m 644 ./sca-L0.conf %{buildroot}/etc/
install -c -m 644 ./README.md %{buildroot}/opt/suse/sca/README.sca-L0
install -c -m 755 ./bin/*.sh %{buildroot}/opt/suse/sca/bin/
install -c -m 644 ./bin/*.py %{buildroot}/opt/suse/sca/bin/
ln -s /opt/suse/sca/bin/sca-L0.sh %{buildroot}/opt/suse/sca/bin/sca-L0
# sca-datasets
mkdir -p %{buildroot}/opt/suse/sca/datasets
install -c -m 644 ./datasets/* %{buildroot}/opt/suse/sca/datasets/
# sca-susedata
mkdir -p %{buildroot}/opt/suse/sca/susedata
install -c -m 644 ./susedata/* %{buildroot}/opt/suse/sca/susedata/

%files
%defattr(-,root,root)
%dir /opt/suse
%dir /opt/suse/sca
/opt/suse/sca/README.sca-L0
/opt/suse/sca/bin
%config /etc/sca-L0.conf

%files -n sca-datasets
%defattr(-,root,root)
%dir /opt/suse
%dir /opt/suse/sca
/opt/suse/sca/datasets

%files -n sca-susedata
%defattr(-,root,root)
%dir /opt/suse
%dir /opt/suse/sca
/opt/suse/sca/susedata

%changelog
