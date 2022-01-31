#include <iostream>
#include <stack>
#include <string>
#include <vector>
#include <fstream>
#include "z3++.h"
#include <omp.h>
#include <math.h>
#include <time.h>

using namespace std;
using namespace z3;

struct TreeNode
{
	string formula;
	int verdict; //true 1; false -1; don't know 0;
	int b1, b2; //interval
	struct TreeNode* left;
	struct TreeNode* right;

	TreeNode()
	{
		formula = "";
		verdict = 0;
		b1 = 0;
		b2 = 0;

		left = NULL;
		right = NULL;
	}

	TreeNode(string val)
	{
		formula = val;
		verdict = 0;
		b1 = 0;
		b2 = 0;

		left = NULL;
		right = NULL;
	}
};

vector<string> listFormula;

class MakeParseTree
{
public:
	MakeParseTree();
	struct TreeNode* getRoot();
	void genTree(string);

private:
	struct TreeNode* root;
	struct TreeNode* makeTree(string, string);
};

MakeParseTree::MakeParseTree()
{
	root = NULL;
}

struct TreeNode* MakeParseTree::getRoot()
{
	return root;
}

void MakeParseTree::genTree(string formula)
{
	string form, formI;
	int flag, flagI = 0;

	stack<string> stack;

	for(int i = 0; i < formula.length(); i++)
	{
		char ch = formula[i];
		if(ch != ' ')
		{
			// cout << ch << " flag:" << flagI << endl;
			if(flagI == 1)
			{
				formI = formI + ch;
				if(ch == ']')
				{
					stack.push(formI);
					flagI = 0;
				}
			}
			else if(flagI == 0)
			{
				if(ch == 'G' || ch == 'U' || ch == 'F')
				{
					formI = ch;
					flagI = 1;
				}
				else if(ch != ')')
					stack.push(string(1, ch));
				else
				{
					form = "";
					flag = 1; //signifying unary operator
					while(!stack.empty())
					{
						string str = stack.top();
						stack.pop();
						// cout << str << endl;
						if(str == "(")
							break;
						else if(str[0] == 'U' || str[0] == '&' || str[0] == '|')
						{
							flag = 2; //signifying binary operator
							form = str + " " + form;
						}
						else
						{
							if(flag == 1)
								form = str + " " + form;
							else
								form = form + str;
						}
					}
					form = "(" + form + ")";
					stack.push(form);
				}
			}
		}
	}

	flag = 1;
	form = "";
	while(!stack.empty())
	{
		string str = stack.top();
		stack.pop();
		if(str == "(")
			break;
		else if(str[0] == 'U' || str[0] == '&' || str[0] == '|' || str[0] == 'I') //until, and, or, implies
		{
			flag = 2; //signifying binary operator
			form = str + " " + form;
		}
		else
		{
			if(flag == 1)
				form = str + " " + form;
			else
				form = form + str;
		}
	}
	// cout << form << endl;

	root = makeTree(form, "");

	// root = new TreeNode("U");
	// root->left = new TreeNode("a");
	// root->right = new TreeNode("b");
}

struct TreeNode* MakeParseTree::makeTree(string subformula, string prefix)
{
	if(subformula.length() == 1) {
		// cout << "Leaf: " << prefix << " " << subformula << endl;
		listFormula.push_back(prefix + " " + subformula);
		struct TreeNode* node = new TreeNode(subformula);
		return node;
	}
	else if(subformula.length() == 0)
		return NULL;
	int numBrac = 0, type;
	string subForm1 = "", subForm2 = "";
	char op = subformula[0];
	string Op = subformula.substr(0, subformula.find(' '));
	if(op == 'U' || op == '|' || op == '&' || op == 'I')
		type = 2;
	else
		type = 1;

	for(int i = Op.length() + 1; i < subformula.length(); i++)
	{
		char ch = subformula[i];

		if(ch == '(')
			numBrac++;
		else if(ch == ')')
			numBrac--;

		// cout << ch << " : " << numBrac << " : " << type << endl;
		if(type == 1) {
			subForm1 = subForm1 + ch;
			if(numBrac == 0)
				break;
		}
		else if(type == 2) {
			subForm2 = subForm2 + ch;
			if(numBrac == 0) {
				type--;
				i++;
			}
		}
	}
	// cout << subformula << " : " << Op << " : " << subForm1 << " : " << subForm2 << endl;
	if(subForm1[0] == '(' && subForm1[subForm1.length() - 1] == ')')
		subForm1 = subForm1.substr(1, subForm1.length() - 2);
	if(subForm2[0] == '(' && subForm2[subForm2.length() - 1] == ')')
		subForm2 = subForm2.substr(1, subForm2.length() - 2);
	// cout << subformula << " : " << subForm1 << ", " << subForm2 << endl;

	struct TreeNode* node = new TreeNode(string(1, op));
	if(op == 'U' || op == 'F' || op == 'G')
	{
		node->b1 = stoi(Op.substr(2, Op.find(',') - Op.find('[')));
		node->b2 = stoi(Op.substr(Op.find(',') + 1));
	}
	// cout << node->b1 << " : " << node->b2 << endl;

	if(op == 'U')
	{
		node->right = makeTree(subForm1, prefix + "G");
		node->left = makeTree(subForm2, prefix + "F");
	}
	else if(op == 'G' || op == 'F')
	{
		node->right = makeTree(subForm1, prefix + op);
		node->left = makeTree(subForm2, prefix + op);
	}
	else
	{
		node->right = makeTree(subForm1, prefix);
		node->left = makeTree(subForm2, prefix);
	}
	return node;
}

class makeSMT
{
public:
	makeSMT();
	makeSMT(string, string);
	void solveSMT();
	vector<int> eventnum;

private:
	string formula;
	string traceFileName;
	vector<vector<string> > eventValueAll;
	vector<vector<int> > eventTimeAll;
	int numProcess;

	struct hb
	{
		int procNum[2];
		hb()
		{
			procNum[0] = 0;
			procNum[1] = 0;
		}
		hb(int a, int b)
		{
			procNum[0] = a;
			procNum[1] = b;
		}
	};
	void createSMT();
	int readTraceFile();
};

makeSMT::makeSMT()
{
	formula = "G((F b) I ((! a) U b))";
	traceFileName = "trace2_20_10";
	eventnum.push_back(1);
	numProcess = 0;
}

makeSMT::makeSMT(string a, string b)
{
	formula = a;
	traceFileName = b;
	eventnum.push_back(1);
	numProcess = 0;
}

int makeSMT::readTraceFile()
{
	ifstream traceFile("traceFiles/swaps/" + traceFileName);
	string line;
	int maxTime = 0;

	while(getline(traceFile, line))
	{
		// cout << line << endl;
		if(line.find("apricot") != -1 || line.find("banana") != -1 || 
			line.find("cherry") != -1 || line.find("Coin") != -1 || 
			line.find("Ticket") != -1)
		{
			eventValueAll.push_back(vector<string>());
			eventTimeAll.push_back(vector<int>());
			numProcess++;
			
			int i = 0;
			while(line.find("logIndex", i) != -1)
			{
				i = line.find("logIndex", i);
				int a = line.find("timestamp", i);
				a = line.find("\"", a + 1);
				a = line.find("\"", a + 1);
				int b = line.find("\"", a + 1);
				string str1 = line.substr(a + 1, b - a);
				int x;
				stringstream geek(str1);
				geek >> x;
				eventTimeAll[numProcess - 1].push_back(x);

				a = line.find("event", i);
				a = line.find("\"", a + 1);
				a = line.find("\"", a + 1);
				b = line.find("\"", a + 1);
				string str2 = line.substr(a + 1, b - a);
				eventValueAll[numProcess - 1].push_back(str2);

				// cout << str2 << " : " << x << endl;
				i = i+1;
			}
		}
	}
	// cout << "numProcess: " << numProcess << endl;
	// for(int i=0;i<numProcess;i++)
	// {
	// 	cout << "processNum: " << i << endl;
	// 	for(int j=0;j<eventValueAll[i].size();j++)
	// 	{
	// 		cout << eventValueAll[i][j] << " : " << eventTimeAll[i][j] << endl;
	// 	}
	// }
	traceFile.close();
	return maxTime;
}

void makeSMT::solveSMT()
{
	int maxTimeTrace = readTraceFile();

	string formula = "G[0,1] (((F[2,3] a) U[4,5] (b U[6,7] c)) & d)";
	MakeParseTree mpt;
	// cout << formula << endl;
	mpt.genTree(formula);

	struct TreeNode* root = mpt.getRoot();

	int tid;
	const int numCores = 1;

	// #pragma omp parallel private(tid) num_threads(numCores)
	// {
	// 	tid = omp_get_thread_num();
	// 	// cout << "ThreadNum:" << tid << endl;
	// 	#pragma omp parallel for
	for(int startSeg = 0; startSeg < numCores; startSeg += 1)
	{
		// cout << "Core: " << tid << " ; " << startSeg << " : " << startSeg + segLength << endl;
		vector<vector<int> > eventNumber;
		vector<struct hb> hbSet;
		int num = 0;
		for(int i = 0; i < numProcess; i++)
		{
			eventNumber.push_back(vector<int>());
			eventNumber[i].push_back(++num);
			for(int j = 1; j < eventValueAll.size(); j++)
			{
				eventNumber[i].push_back(++num);
				hbSet.push_back(hb(eventNumber[i][j-1], eventNumber[i][j]));
			}
		}

		int totNumEvents = 0;
		vector<int> numEventProc;
		for(int i = 0; i < numProcess; i++)
		{
			numEventProc.push_back(eventValueAll[i].size());
			totNumEvents = totNumEvents + numEventProc[i];
		}
		cout << "totNumEvents: " << totNumEvents << endl;
		totNumEvents = totNumEvents/2;

		for(int tot = 0; tot < 2; tot++)
		{
			cout << "totNumEvents: " << totNumEvents << endl;
			if(tot == 1)
				totNumEvents++;

		// int totNumFormulas = listFormula.size();
		int totNumFormulas = 1;

		context c;
		solver s(c);

		expr_vector eventList(c);

		//making a vector of all possible consistent cuts
		for(int i = 0; i < pow(2, totNumEvents); i++)
	    {
	        string str = "eventList" + to_string(i);
	        eventList.push_back(c.bv_const(str.c_str(), totNumEvents));
	        s.add(eventList[i] == i);
	    }

	    //defining our uninterpreted function
	    func_decl rho = z3::function("rho", c.int_sort(), c.bv_sort(totNumEvents));

	    //the first consistent cut should be the empty cut: without any event
	    s.add(rho(0) == eventList[0]);

	    //each consistent cut can be any of the consistent cut
	    for (int i = 0; i <= totNumEvents; i++)
	    {
	        expr_vector event_range(c);
	  
	        for (int j = 0; j < pow(2, totNumEvents); j++)
	        {
	            event_range.push_back(rho(i) == eventList[j]);
	        }

	        s.add(mk_or(event_range));
	    }

	    //the difference between two consecutive entry of the uninterpreted function should be a power of 2
	    for(int i = 0; i < totNumEvents; i++)
	    {
	        expr_vector event_order(c);

	        for(int j = 1; j < pow(2, totNumEvents); j = j * 2)
	            event_order.push_back(bv2int(rho(i + 1), false) - bv2int(rho(i), false) == j);

	        // s.add(rho(i + 1) > rho(i));
	        s.add(mk_or(event_order));
	    }

	    //the last consistent cut should be the consistent cut with all the events in it
	    s.add(rho(totNumEvents) == eventList[eventList.size() - 1]);

	    expr x = c.int_const("x");
	    s.add(0 <= x && x <= totNumEvents);

	    expr_vector b1(c);
	    expr_vector b2(c);

	    //consistent cuts should take into consideration the happen-before relationship between events across processes
	    for(int i = 0; i < hbSet.size(); i++)
	    {
	        string str = "b1" + std::to_string(i);
	        b1.push_back(c.bv_const(str.c_str(), totNumEvents));
	        str = "b2" + std::to_string(i);
	        b2.push_back(c.bv_const(str.c_str(), totNumEvents));
	        int p0 = (int)pow(2, hbSet[i].procNum[0] - 1);
	        int p1 = (int)pow(2, hbSet[i].procNum[1] - 1);

	        s.add(b1[i] == p1);
	        s.add(b2[i] == p0);
	        s.add(forall(x, implies(bv2int(rho(x) & b1[i], false) != 0, bv2int(rho(x) & b2[i], false) != 0)));
	    }

	    // expr_vector val1(c);

	    // for(int i = 0; i < pow(2, totNumEvents); i++)
	    // {
	    // 	string str = "val1" + to_string(i);
	    // 	val1.push_back(c.int_const(str.c_str()));
	    // 	s.add(val1[i] == 1);
	    // }

	    // //val-setUp
	    // expr v1 = c.int_const("v1");
	    // s.add(1 <= v1 && v1 <= totNumEvents);
	    // s.add(implies(1 <= v1 && v1 <= totNumEvents, exists(v1, val1[bv2int(rho(v1), totNumEvents)] == 1)));
	    // check_result setUpStr = s.check();
	    // // cout << "SetUp: " << setUpStr << endl;

	    // //val-Apricot-Premium
	    // expr v2 = c.int_const("v2");
	    // s.add(1 <= v2 && v2 <= totNumEvents);
	    // s.add(implies(1 <= v2 && v2 <= totNumEvents, exists(v2, val1[bv2int(rho(v2), totNumEvents)] == 1)));
	    // check_result aprPremium = s.check();
	    // // cout << "Apricot-Premium: " << aprPremium << endl;

	    // //val-Apricot-Premium-Order
	    // expr v21 = c.int_const("v21");
	    // expr v22 = c.int_const("v22");
	    // s.add(1 <= v21 && v21 <= totNumEvents);
	    // s.add(1 <= v22 && v22 <= 2);
	    // s.add(implies(1 <= v21 && v21 <= totNumEvents, forall(v21, implies(1 <= v21 + v22 && v21 + v22 <= totNumEvents, 
	    // 	exists(v22, val1[bv2int(rho(v21 + v22), totNumEvents)] == 1)))));
	    // check_result aprPremiumOrder = s.check();
	    // // cout << "Apricot-Premium-Order: " << aprPremiumOrder << endl;

	    // //val-Apricot-Escrow
	    // expr v3 = c.int_const("v3");
	    // s.add(1 <= v3 && v3 <= totNumEvents);
	    // s.add(implies(1 <= v3 && v3 <= totNumEvents, exists(v3, val1[bv2int(rho(v3), totNumEvents)] == 1)));
	    // check_result aprEscrow = s.check();
	    // // cout << "Apricot-Escrow: " << aprEscrow << endl;

	    // //val-Apricot-Escrow-Order
	    // expr v31 = c.int_const("v31");
	    // expr v32 = c.int_const("v32");
	    // s.add(1 <= v31 && v31 <= totNumEvents);
	    // s.add(1 <= v32 && v32 <= 2);
	    // s.add(implies(1 <= v31 && v31 <= totNumEvents, forall(v31, implies(1 <= v31 + v32 && v31 + v32 <= totNumEvents, 
	    // 	exists(v32, val1[bv2int(rho(v31 + v32), totNumEvents)] == 1)))));
	    // check_result aprEscrowOrder = s.check();
	    // // cout << "Apricot-Escrow-Order: " << aprEscrowOrder << endl;

	    // //val-Apricot-Redeem
	    // expr v4 = c.int_const("v4");
	    // s.add(1 <= v4 && v4 <= totNumEvents);
	    // s.add(implies(1 <= v4 && v4 <= totNumEvents, exists(v4, val1[bv2int(rho(v4), totNumEvents)] == 1)));
	    // check_result aprRedeem = s.check();
	    // // cout << "Apricot-Redeem: " << aprRedeem << endl;

	    // //val-Apricot-Redeem-Order
	    // expr v41 = c.int_const("v41");
	    // expr v42 = c.int_const("v42");
	    // s.add(1 <= v41 && v41 <= totNumEvents);
	    // s.add(1 <= v42 && v42 <= 2);
	    // s.add(implies(1 <= v41 && v41 <= totNumEvents, forall(v41, implies(1 <= v41 + v42 && v41 + v42 <= totNumEvents, 
	    // 	exists(v42, val1[bv2int(rho(v41 + v42), totNumEvents)] == 1)))));
	    // check_result aprRedeemOrder = s.check();
	    // // cout << "Apricot-Redeem-Order: " << aprRedeemOrder << endl;

	    // //val-Banana-Premium
	    // expr v5 = c.int_const("v5");
	    // s.add(1 <= v5 && v5 <= totNumEvents);
	    // s.add(implies(1 <= v5 && v5 <= totNumEvents, exists(v5, val1[bv2int(rho(v5), totNumEvents)] == 1)));
	    // check_result banPremium = s.check();
	    // // cout << "Banana-Premium: " << banPremium << endl;

	    // //val-Banana-Premium-Order
	    // expr v51 = c.int_const("v51");
	    // expr v52 = c.int_const("v52");
	    // s.add(1 <= v51 && v51 <= totNumEvents);
	    // s.add(1 <= v52 && v52 <= 2);
	    // s.add(implies(1 <= v51 && v51 <= totNumEvents, forall(v51, implies(1 <= v51 + v52 && v51 + v52 <= totNumEvents, 
	    // 	exists(v52, val1[bv2int(rho(v51 + v52), totNumEvents)] == 1)))));
	    // check_result banPremiumOrder = s.check();
	    // // cout << "Banana-Premium-Order: " << banPremiumOrder << endl;

	    // //val-Banana-Escrow
	    // expr v6 = c.int_const("v6");
	    // s.add(1 <= v6 && v6 <= totNumEvents);
	    // s.add(implies(1 <= v6 && v6 <= totNumEvents, exists(v6, val1[bv2int(rho(v6), totNumEvents)] == 1)));
	    // check_result banEscrow = s.check();
	    // // cout << "Banana-Escrow: " << banEscrow << endl;

	    // //val-Banana-Escrow-Order
	    // expr v61 = c.int_const("v61");
	    // expr v62 = c.int_const("v62");
	    // s.add(1 <= v61 && v61 <= totNumEvents);
	    // s.add(1 <= v62 && v62 <= 2);
	    // s.add(implies(1 <= v61 && v61 <= totNumEvents, forall(v61, implies(1 <= v61 + v62 && v61 + v62 <= totNumEvents, 
	    // 	exists(v62, val1[bv2int(rho(v61 + v62), totNumEvents)] == 1)))));
	    // check_result banEscrowOrder = s.check();
	    // // cout << "Banana-Escrow-Order: " << banEscrowOrder << endl;

	    // //val-Banana-Redeem
	    // expr v7 = c.int_const("v7");
	    // s.add(1 <= v7 && v7 <= totNumEvents);
	    // s.add(implies(1 <= v7 && v7 <= totNumEvents, exists(v7, val1[bv2int(rho(v7), totNumEvents)] == 1)));
	    // check_result banRedeem = s.check();
	    // // cout << "Banana-Redeem: " << banRedeem << endl;

	    // //val-Banana-Redeem-Order
	    // expr v71 = c.int_const("v71");
	    // expr v72 = c.int_const("v72");
	    // s.add(1 <= v71 && v71 <= totNumEvents);
	    // s.add(1 <= v72 && v72 <= 2);
	    // s.add(implies(1 <= v71 && v71 <= totNumEvents, forall(v71, implies(1 <= v71 + v72 && v71 + v72 <= totNumEvents, 
	    // 	exists(v72, val1[bv2int(rho(v71 + v72), totNumEvents)] == 1)))));
	    // check_result banRedeemOrder = s.check();
	    // cout << "Banana-Redeem-Order: " << banRedeemOrder << endl;

	    //val-Liveness
	    // if(aprEscrow == sat && aprPremium == sat && aprRedeem == sat && banPremium == sat && banEscrow == sat && banRedeem == sat)
	    // 	cout << "Livesness: sat" << endl;
	    // else
	    // 	cout << "Liveness: unsat" << endl;

	    //val-Safety


	    //val-Hedged
	}
		break;

	}
	// }
}

class mainProg
{
public:
	void execute();

private:
	float findAverage(vector<float>);
	float findStdDeviation(vector<float>, float);
};

float mainProg::findAverage(vector<float> nums)
{
	float sum = 0;
	for(int  i = 0; i < nums.size(); i++)
	{
		sum = sum + nums[i];
	}

	return sum / nums.size();
}

float mainProg::findStdDeviation(vector<float> nums, float avg)
{
	float sum = 0;
	for(int  i = 0; i < nums.size(); i++)
	{
		sum = sum + pow(nums[i] - avg, 2);
	}

	return (sqrt(sum) / nums.size());
}

void mainProg::execute()
{
	ofstream outFile;
	outFile.open("result.csv");
	outFile << "fileNum, mean, sd" << endl;
	for(int fileNum = 3087; fileNum >= 0; fileNum--)
	{
		int numIter = 1;

		vector<float> resultTime;
		for(int  i = 0; i < numIter; i++)
		{
			// makeSMT smt("[] a", "two_party_swap_" + to_string(fileNum) + ".json");
			// makeSMT smt("[] a", "three_party_swap_" + to_string(fileNum) + ".json");
			makeSMT smt("[] a", "auction_" + to_string(fileNum) + ".json");
			clock_t runTime = clock();
			smt.solveSMT();
			runTime = clock() - runTime;
			float exeTime = (float) runTime / CLOCKS_PER_SEC;
			cout << exeTime << endl;
			resultTime.push_back(exeTime);
		}
		float avg = findAverage(resultTime);
		float sd = findStdDeviation(resultTime, avg);

		cout << "fileNum: " << fileNum << " mean: " << avg << " sd: " << sd << endl;
		outFile << fileNum << ", " << avg << ", " << sd << endl;
	}

	outFile.close();
}

int main()
{
	mainProg obj;
	obj.execute();

	return 1;
}
