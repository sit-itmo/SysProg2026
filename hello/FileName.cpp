#include <stdio.h>
#include <windows.h>

int main()
{
	const char* p_text = "Hello from User!";
	unsigned long long addr = (unsigned long long)p_text;

	while (1)
	{
		printf("\n%s => 0x%llx!", p_text, addr);
		Sleep(1000);
	}
	return 0;
}