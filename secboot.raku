use NativeCall;

sub MAIN {
  given $*KERNEL {
    when 'win32' {
      constant \SystemBootEnvironmentInformation = 0x5A;
      constant \SystemSecureBootInformation = 0x91;

      class GUID is repr('CStruct') {
        has uint32 $.Data1;
        has uint16 $.Data2;
        has uint16 $.Data3;
        HAS  uint8 @.Data[8] is CArray;
      }

      enum FIRMWARE_TYPE <Unknown BIOS UEFI Max>;

      class SYSTEM_BOOT_ENVIRONMENT_INFORMATION is repr('CStruct') {
        HAS GUID $.BootIdentifier;
        has uint32 $.FirmwareType;
        has uint64 $.BootFlags;

        method type {
          return FIRMWARE_TYPE($!FirmwareType);
        }

        method size {
          return nativesizeof(self);
        }
      }

      class SYSTEM_SECUREBOOT_INFORMATION is repr('CStruct') {
        has uint8 $.SecureBootEnabled;
        has uint8 $.SecureBootCapable;

        method size {
          return nativesizeof(self);
        }
      }

      sub FormatMessageW(
        uint32, Pointer, uint32, uint32, CArray[uint16], uint32, Pointer
      ) is native('kernelbase.dll') returns uint32 {*};

      sub GetLastError is native('kernelbase.dll') returns uint32 {*};

      sub NtQuerySystemInformation(
        uint32, CArray[uint8], uint32, Pointer
      ) is native('ntdll.dll') returns int32 {*};

      sub RtlNtStatusToDosError(int32) is native('ntdll.dll') returns uint32 {*};

      sub getlasterror(uint32 $err) {
        my $buf = CArray[uint16].new(0 xx 0xFF);
        my $len = FormatMessageW(
          0x10FF, # FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_MAX_WIDTH_MASK
          Pointer[void], $err, 0x400, # MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT)
          $buf, $buf.elems, Pointer[void]
        );
        if 0 == $len {
          '[!] Unknown error has been occured.'.say;
          return;
        }
        $buf[0..$len].map(*.chr).join.say;
      }

      my SYSTEM_BOOT_ENVIRONMENT_INFORMATION $sbi .= new;
      my $buf = nativecast(CArray[uint8], $sbi);
      my $nts = NtQuerySystemInformation(SystemBootEnvironmentInformation, $buf, $sbi.size, Pointer[void]);

      if 0 != $nts {
        getlasterror(RtlNtStatusToDosError($nts));
        return;
      }

      if 'UEFI' ne $sbi.type {
        '[!] The firmware type of boot device is not UEFI.'.say;
        return;
      }

      my SYSTEM_SECUREBOOT_INFORMATION $ssi .= new;
      $buf = nativecast(CArray[uint8], $ssi);
      $nts = NtQuerySystemInformation(SystemSecureBootInformation, $buf, $ssi.size, Pointer[void]);

      if 0 != $nts {
        getlasterror(RtlNtStatusToDosError($nts));
        return;
      }

      "[*] Secure boot is $($ssi.SecureBootEnabled ?? 'enabled' !! 'disabled').".say;
    } # win32
    default {
      '[*] Not implemented at the current time.'.say;
    } # other
  }
}
