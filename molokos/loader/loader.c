#include <efi.h>

#define KERNEL_PATH L"\\kernel\\kernel.elf"
#define PT_LOAD 1

typedef struct {
    unsigned char e_ident[16];
    UINT16 e_type;
    UINT16 e_machine;
    UINT32 e_version;
    UINT64 e_entry;
    UINT64 e_phoff;
    UINT64 e_shoff;
    UINT32 e_flags;
    UINT16 e_ehsize;
    UINT16 e_phentsize;
    UINT16 e_phnum;
    UINT16 e_shentsize;
    UINT16 e_shnum;
    UINT16 e_shstrndx;
} Elf64_Ehdr;

typedef struct {
    UINT32 p_type;
    UINT32 p_flags;
    UINT64 p_offset;
    UINT64 p_vaddr;
    UINT64 p_paddr;
    UINT64 p_filesz;
    UINT64 p_memsz;
    UINT64 p_align;
} Elf64_Phdr;

typedef void (*kernel_entry_t)(EFI_SYSTEM_TABLE *system_table);

static EFI_SYSTEM_TABLE *g_st;
static EFI_BOOT_SERVICES *g_bs;

static void *memcpy_local(void *dst, const void *src, UINTN n) {
    UINT8 *d = (UINT8 *)dst;
    const UINT8 *s = (const UINT8 *)src;
    for (UINTN i = 0; i < n; i++) d[i] = s[i];
    return dst;
}

static void *memset_local(void *dst, UINT8 v, UINTN n) {
    UINT8 *d = (UINT8 *)dst;
    for (UINTN i = 0; i < n; i++) d[i] = v;
    return dst;
}

static void loader_puts(const char *s) {
    CHAR16 buf[256];
    UINTN i = 0;
    while (s[i] != '\0' && i < (sizeof(buf) / sizeof(buf[0])) - 3) {
        buf[i] = (CHAR16)(unsigned char)s[i];
        i++;
    }
    buf[i++] = L'\r';
    buf[i++] = L'\n';
    buf[i] = L'\0';
    g_st->ConOut->OutputString(g_st->ConOut, buf);
}

static EFI_STATUS read_file(EFI_HANDLE ImageHandle, CHAR16 *path, void **out_buf, UINTN *out_size) {
    EFI_STATUS st;
    EFI_LOADED_IMAGE *loaded;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *sfs;
    EFI_FILE_PROTOCOL *root;
    EFI_FILE_PROTOCOL *file;
    EFI_GUID lip = EFI_LOADED_IMAGE_PROTOCOL_GUID;
    EFI_GUID sfsp = EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID;
    EFI_GUID file_info_guid = EFI_FILE_INFO_ID;

    st = g_bs->HandleProtocol(ImageHandle, &lip, (void **)&loaded);
    if (EFI_ERROR(st)) return st;

    st = g_bs->HandleProtocol(loaded->DeviceHandle, &sfsp, (void **)&sfs);
    if (EFI_ERROR(st)) return st;

    st = sfs->OpenVolume(sfs, &root);
    if (EFI_ERROR(st)) return st;

    st = root->Open(root, &file, path, EFI_FILE_MODE_READ, 0);
    if (EFI_ERROR(st)) return st;

    UINTN info_sz = SIZE_OF_EFI_FILE_INFO + 512;
    EFI_FILE_INFO *info = NULL;
    st = g_bs->AllocatePool(EfiLoaderData, info_sz, (void **)&info);
    if (EFI_ERROR(st)) return st;

    st = file->GetInfo(file, &file_info_guid, &info_sz, info);
    if (EFI_ERROR(st)) return st;

    *out_size = (UINTN)info->FileSize;
    st = g_bs->AllocatePool(EfiLoaderData, *out_size, out_buf);
    if (EFI_ERROR(st)) return st;

    st = file->Read(file, out_size, *out_buf);
    return st;
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    g_st = SystemTable;
    g_bs = SystemTable->BootServices;

    loader_puts("loader: reading kernel");

    void *elf_buf = NULL;
    UINTN elf_sz = 0;
    EFI_STATUS st = read_file(ImageHandle, KERNEL_PATH, &elf_buf, &elf_sz);
    if (EFI_ERROR(st)) {
        loader_puts("loader: failed to read kernel.elf");
        return st;
    }

    Elf64_Ehdr *eh = (Elf64_Ehdr *)elf_buf;
    if (!(eh->e_ident[0] == 0x7F && eh->e_ident[1] == 'E' && eh->e_ident[2] == 'L' && eh->e_ident[3] == 'F' && eh->e_ident[4] == 2)) {
        loader_puts("loader: invalid ELF64");
        return EFI_LOAD_ERROR;
    }

    Elf64_Phdr *ph = (Elf64_Phdr *)((UINT8 *)elf_buf + eh->e_phoff);
    for (UINTN i = 0; i < eh->e_phnum; i++) {
        if (ph[i].p_type != PT_LOAD) continue;

        EFI_PHYSICAL_ADDRESS seg = (EFI_PHYSICAL_ADDRESS)ph[i].p_paddr;
        UINTN pages = (UINTN)((ph[i].p_memsz + 0xFFF) >> 12);

        st = g_bs->AllocatePages(AllocateAddress, EfiLoaderData, pages, &seg);
        if (EFI_ERROR(st)) {
            loader_puts("loader: AllocatePages failed");
            return st;
        }

        memcpy_local((void *)(UINTN)seg, (UINT8 *)elf_buf + ph[i].p_offset, (UINTN)ph[i].p_filesz);
        if (ph[i].p_memsz > ph[i].p_filesz) {
            memset_local((UINT8 *)(UINTN)seg + ph[i].p_filesz, 0, (UINTN)(ph[i].p_memsz - ph[i].p_filesz));
        }
    }

    loader_puts("loader: jumping to kernel entry");
    kernel_entry_t entry = (kernel_entry_t)(UINTN)eh->e_entry;
    entry(SystemTable);

    loader_puts("loader: kernel returned unexpectedly");
    return EFI_SUCCESS;
}
