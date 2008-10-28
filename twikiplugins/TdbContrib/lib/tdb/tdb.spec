%define name	tdb
%define version	1.0.5
%define release	1
%define serial  1

Summary: a trivial database system
Name:	 %{name}
Version: %{version}
Release: %{release}
Serial:	 %{serial}
Copyright: GPL
Group:	Development/Libraries
URL:	 http://sourceforge.net/projects/tdb/
Source:	 http://prdownloads.sourceforge.net/tdb/%{name}-%{version}.tar.gz
Buildroot: /var/tmp/%{name}-%{version}

Packager: Jonathon D Nelson <jnelson@securepipe.com>

%changelog
* Mon Dec 10 2001 Ben Woodard <ben@zork.net>
- Bumped up the version number
- changed email addrs.

* Thu May 23 2001 Jonathon D Nelson <jnelson@securepipe.com>
- Created redhat packages.

%description
This is a simple database API. It was inspired by the realisation that
in Samba we have several ad-hoc bits of code that essentially
implement small databases for sharing structures between parts of
Samba. As I was about to add another I realised that a generic
database module was called for to replace all the ad-hoc bits.

I based the interface on gdbm. I couldn't use gdbm as we need to be
able to have multiple writers to the databases at one time.

(I == tridge@samba.org)

This is the primary library.

%package devel
Summary: a trivial database system development files
Group: Development/Libraries
Requires: tdb
%description devel
This is a simple database API. It was inspired by the realisation that
in Samba we have several ad-hoc bits of code that essentially
implement small databases for sharing structures between parts of
Samba. As I was about to add another I realised that a generic
database module was called for to replace all the ad-hoc bits.

I based the interface on gdbm. I couldn't use gdbm as we need to be
able to have multiple writers to the databases at one time.

(I == tridge@samba.org)

These are the development files.

%prep
%setup

%build
CFLAGS="$RPM_OPT_FLAGS" \
./configure --prefix=/usr

make

%install
if [ -d $RPM_BUILD_ROOT ]; then rm -rf $RPM_BUILD_ROOT/ ; fi
make DESTDIR=$RPM_BUILD_ROOT install

%post	-p /sbin/ldconfig

%postun	-p /sbin/ldconfig

%clean
if [ -d $RPM_BUILD_ROOT ]; then rm -rf $RPM_BUILD_ROOT/; fi

%files 
%defattr(-,root,root)
%doc AUTHORS COPYING INSTALL NEWS README TODO ChangeLog
/usr/lib/*.so.*

%files devel
%defattr(-,root,root)
/usr/include/*
/usr/lib/*.a
/usr/lib/*.la
/usr/man/man3/*
