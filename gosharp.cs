using System;

namespace GoSharp
{
	class Driver
	{
		static private string[] AssemblyList = {"BinaryTree17", "Fannkuch11", "FmtFprintfEmpty.exe", "FmtFprintfInt.exe", "FmtFprintfString.exe"};
		static void Main()
		{
			foreach (var testName in AssemblyList)
			{
				AppDomain.CurrentDomain.ExecuteAssembly("./cil/" + testName + ".exe");
			}
		}
	}
}

