using System;

namespace GoSharp
{
	class Driver
	{
		static void Main(string[] args)
		{
			foreach (var testName in args)
			{
				AppDomain.CurrentDomain.ExecuteAssembly("./cil/" + testName + ".exe");
			}
		}
	}
}

