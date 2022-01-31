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
	void solveSMT(int, int);

private:
	string formula;
	string traceFileName;
	struct HLCTime
	{
		int timeVal[3];
		HLCTime()
		{
			timeVal[0] = 0;
			timeVal[1] = 0;
			timeVal[2] = 0;
		}
		HLCTime(int l, int m, int c)
		{
			timeVal[0] = l;
			timeVal[1] = m;
			timeVal[2] = c;
		}
	};
	vector<vector<string> > eventValueAll;
	vector<vector<struct HLCTime> > eventTimeAll;
	vector<vector<char> > eventTypeAll;
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

	numProcess = 0;
}

makeSMT::makeSMT(string a, string b)
{
	formula = a;
	traceFileName = b;

	numProcess = 0;
}

int makeSMT::readTraceFile()
{
	ifstream traceFile("traceFiles/" + traceFileName);
	string line;
	int maxTime = 0;

	while(getline(traceFile, line))
	{
		// cout << line << endl;
		if(line.find("System") != -1 || line.find("\\Process") != -1)
			continue;
		else if(line.find("Process") != -1) {
			eventTypeAll.push_back(vector<char>());
			eventValueAll.push_back(vector<string>());
			eventTimeAll.push_back(vector<struct HLCTime>());
			numProcess++;
		}
		else
		{
			int a = line.find("=");
			a = line.find("=", a + 1);
			a = line.find("\"", a + 1);
			int b = line.find("\"", a + 1);
			int c = line.find("\"", b + 1);
			int d = line.find("\"", c + 1);
			int e = line.find("\"", d + 1);
			int f = line.find("\"", e + 1);
			// cout << numProcess << endl;
			eventTypeAll[numProcess - 1].push_back(line.substr(a + 1, b - a - 1)[0]);
			eventValueAll[numProcess - 1].push_back(line.substr(c + 1, d - c - 1));
			string time = line.substr(e + 1, f - e - 2);
			a = time.find(",");
			b = time.find(",", a + 1);
			maxTime = max(maxTime, stoi(time.substr(1, a - 1)));
			eventTimeAll[numProcess - 1].push_back(HLCTime(stoi(time.substr(1, a - 1)), stoi(time.substr(a + 2, b - a - 2)), stoi(time.substr(b + 2))));
		}
	}
	// cout << "numProcess: " << numProcess << endl;
	// for(int i=0;i<numProcess;i++)
	// {
	// 	cout << "processNum: " << i << " eventNum: " << eventTypeAll[i].size() << endl;
	// 	for(int j=0;j<eventTypeAll[i].size();j++)
	// 	{
	// 		cout << eventTypeAll[i][j] << " : " << eventValueAll[i][j] << endl;
	// 		cout << eventTimeAll[i][j].timeVal[0] << " : " << eventTimeAll[i][j].timeVal[1] << " : " << eventTimeAll[i][j].timeVal[2] << endl;
	// 	}
	// }
	traceFile.close();
	return maxTime;
}

void makeSMT::solveSMT(int segLength, int eps)
{
	int maxTimeTrace = readTraceFile();

	string formula = "G[0,1] (((F[2,3] a) U[4,5] (b U[6,7] c)) & d)";
	MakeParseTree mpt;
	// cout << formula << endl;
	mpt.genTree(formula);

	struct TreeNode* root = mpt.getRoot();

	int tid;
	const int numCores = 1;

	#pragma omp parallel private(tid) num_threads(numCores)
	{
		tid = omp_get_thread_num();
		// cout << "ThreadNum:" << tid << endl;
		#pragma omp parallel for
		for(int startSeg = (maxTimeTrace / numCores) * tid; startSeg < (maxTimeTrace / numCores) * (tid + 1); startSeg += segLength)
		{
			// cout << "Core: " << tid << " ; " << startSeg << " : " << startSeg + segLength << endl;

			//clean the data for the segment needed
			int start = max(startSeg - eps, 0);
			int end = startSeg + segLength;
			vector<vector<int> > eventNumber;
			vector<vector<string> > eventValueSeg;
			vector<vector<struct HLCTime> > eventTimeSeg;
			vector<vector<char> > eventTypeSeg;
			vector<struct hb> hbSet;
			// cout << start << " : " << end << endl;
			int num = 0;
			for(int i = 0; i < numProcess; i++)
			{
				eventTypeSeg.push_back(vector<char>());
				eventValueSeg.push_back(vector<string>());
				eventTimeSeg.push_back(vector<struct HLCTime>());
				eventNumber.push_back(vector<int>());
				for(int j = 0; j < eventTypeAll[i].size(); j++)
				{
					if(eventTimeAll[i][j].timeVal[0] >= start && eventTimeAll[i][j].timeVal[0] <= end)
					{
						eventNumber[i].push_back(++num);
						eventTypeSeg[i].push_back(eventTypeAll[i][j]);
						eventValueSeg[i].push_back(eventValueAll[i][j]);
						eventTimeSeg[i].push_back(HLCTime(eventTimeAll[i][j].timeVal[0], eventTimeAll[i][j].timeVal[1], eventTimeAll[i][j].timeVal[2]));
					}
				}
			}

			for(int i = 0; i < numProcess; i++)
			{
				for(int j = 0; j < eventTypeSeg[i].size(); j++)
				{
					if(eventTypeSeg[i][j] == 'R')
					{
						for(int k = 0; k < numProcess; k++)
						{
							for(int l = 0; l < eventTypeSeg[k].size() && k != i; l++)
							{
								if(eventTypeSeg[k][l] == 'S' && eventTimeSeg[k][l].timeVal[0] == stoi(eventValueSeg[i][j].substr(0, eventValueSeg[i][j].find(","))))
								{
									hbSet.push_back(hb(eventNumber[k][l], eventNumber[i][j]));
									// cout << "happenBefore: " << eventNumber[k][l] << " " << eventNumber[i][j] << endl;
								}
							}
						}
					}
					for(int k = 0; k < numProcess; k++)
					{
						for(int l = 0; l < eventTypeSeg[k].size() && k != i; l++)
						{
							if(abs(eventTimeSeg[i][j].timeVal[0] - eventTimeSeg[k][l].timeVal[0]) >= eps)
							{
								hbSet.push_back(hb(eventNumber[k][l], eventNumber[i][j]));
								// cout << "happenBefore: " << eventNumber[k][l] << " " << eventNumber[i][j] << endl;
							}
						}
					}
				}
			}

			int totNumEvents = 0;
			vector<int> numEventProc;
			for(int i = 0; i < numProcess; i++)
			{
				numEventProc.push_back(eventTypeSeg[i].size());
				totNumEvents = totNumEvents + numEventProc[i];
			}
			// cout << "totNumEvents: " << totNumEvents << endl;

			// int totNumFormulas = listFormula.size();
			int totNumFormulas = 2;
			// if(startSeg == 0)
			// 	totNumFormulas = 2;
			// else
				// totNumFormulas = 3;

			for(int numFormula = 0; numFormula < 2 * totNumFormulas; numFormula ++)
			{
				// cout << listFormula[numFormula] << endl;

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

			    func_decl event_time = z3::function("event_time", c.int_sort(), c.int_sort());

			    for(int i1 = 0; i1 < eventTimeSeg.size(); i1++)
			    {
			    	for(int i2 = 0; i2 < eventTimeSeg[i1].size(); i2++)
			    	{
				        expr_vector time_range(c);
				        
				        for(int j = max(0, eventTimeSeg[i1][i2].timeVal[0] - eps + 1); j < eventTimeSeg[i1][i2].timeVal[0] + eps - 1; j++)
				            time_range.push_back(event_time(eventNumber[i1][i2] - 1) == j);

				        s.add(mk_or(time_range));
				    }
			    }

			    func_decl time_seq = z3::function("time_seq", c.int_sort(), c.int_sort());

			    for(int i1 = 0; i1 < eventTimeSeg.size(); i1++)
			    {
			    	for(int i2 = 0; i2 < eventTimeSeg[i1].size(); i2++)
			    	{
				        expr_vector time_seq_domain(c);

				        for(int j = 0; j < totNumEvents; j++)
				            time_seq_domain.push_back(time_seq(eventNumber[i1][i2] - 1) == event_time(j));

				        s.add(mk_or(time_seq_domain));
				    }
			    }

			    expr y = c.int_const("y");
			    s.add(0 <= y && y <= totNumEvents);

			    for(int i1 = 0; i1 < eventTimeSeg.size(); i1++)
			    {
			    	for(int i2 = 0; i2 < eventTimeSeg[i1].size(); i2++)
			    	{
			    		int i = eventNumber[i1][i2] - 1;
				        int p = (int)pow(2, i);

				        s.add(exists(y, implies(bv2int(rho(y), false) - bv2int(rho(y+1), false) == p, 
			            	time_seq(y) == event_time(i))));
				    }
			    }

			    expr_vector val1(c);

			    for(int i = 0; i < pow(2, totNumEvents); i++)
			    {
			    	string str = "val1" + to_string(i);
			    	val1.push_back(c.int_const(str.c_str()));
			    	if(i == 2)
			    		s.add(val1[i] == 1);
			    	else
			    		s.add(val1[i] == 0);
			    }

			    //test1 and test2
			    // expr v1 = c.int_const("v1");
			    // s.add(1 <= v1 && v1 <= totNumEvents);
			    // s.add(implies(1 <= v1 && v1 <= totNumEvents, exists(v1, val1[bv2int(rho(v1), totNumEvents)] == 1)));

			    //test3
			    // expr v1 = c.int_const("v1");
			    // if(numFormula == 0 || numFormula == 1)
			    // {
				   //  s.add(1 <= v1 && v1 <= totNumEvents);
				   //  s.add(implies(1 <= v1 && v1 <= totNumEvents, forall(v1, val1[bv2int(rho(v1), totNumEvents)] == 1)));
			    // }
			    // else
			    // {
				   //  s.add(1 <= v1 && v1 <= totNumEvents);
				   //  s.add(implies(1 <= v1 && v1 <= totNumEvents, exists(v1, val1[bv2int(rho(v1), totNumEvents)] == 1)));
			    // }

			    //test4
			    expr v1 = c.int_const("v1");
			    expr v2 = c.int_const("v2");
			    if(numFormula == 0 || numFormula == 1)
			    {
				    s.add(1 <= v1 && v1 <= totNumEvents);
				    s.add(1 <= v2 && v2 <= 2);
				    s.add(implies(1 <= v1 && v1 <= totNumEvents, forall(v1, implies(1 <= v1 + v2 && v1 + v2 <= totNumEvents, 
				    	exists(v2, val1[bv2int(rho(v1 + v2), totNumEvents)] == 1)))));
				}
				else
				{
					s.add(1 <= v2 && v2 <= 2);
				    s.add(exists(v2, val1[bv2int(rho(v2), totNumEvents)] == 1));
				}

				//test5
			 //    expr v1 = c.int_const("v1");
			 //    if(numFormula == 0 || numFormula == 1)
			 //    {
				//     s.add(1 <= v1 && v1 <= totNumEvents);
				//     s.add(implies(1 <= v1 && v1 <= totNumEvents, forall(v1, val1[bv2int(rho(v1), totNumEvents)] == 1)));
				// }
				// else
				// {
				// 	s.add(1 <= v1 && v1 <= totNumEvents);
				//     s.add(implies(1 <= v1 && v1 <= totNumEvents, exists(v1, val1[bv2int(rho(v1), totNumEvents)] == 1)));
				// }

			    //test6
			 //    expr v1 = c.int_const("v1");
				// expr v2 = c.int_const("v2");
			 //    if(numFormula == 0 || numFormula == 1)
			 //    {
				//     s.add(1 <= v1 && v1 <= totNumEvents);
				//     s.add(1 <= v2 && v2 <= 2);
				//     s.add(implies(1 <= v1 && v1 <= totNumEvents, forall(v1, implies(1 <= v1 + v2 && v1 + v2 <= totNumEvents, 
				//     	forall(v2, val1[bv2int(rho(v1 + v2), totNumEvents)] == 1)))));
			 //    }
			 //    else if(numFormula == 2 || numFormula == 3)
			 //    {
				//     s.add(1 <= v1 && v1 <= totNumEvents);
				//     s.add(1 <= v2 && v2 <= 2);
				//     s.add(implies(1 <= v1 && v1 <= totNumEvents, exists(v1, implies(1 <= v1 + v2 && v1 + v2 <= totNumEvents, 
				//     	forall(v2, val1[bv2int(rho(v1 + v2), totNumEvents)] == 1)))));
			 //    }
			 //    else
			 //    {
			 //    	s.add(1 <= v2 && v2 <= 2);
				//     s.add(exists(v2, val1[bv2int(rho(v2), totNumEvents)] == 1));
			 //    }

			    // if(s.check() == sat)
			    // {
		    	// 	model m = s.get_model();
		    	// 	cout << "Sat: " << m[v1] << endl;
		    	// 	// s.add(v1 != bv2int(eventList[i], totNumEvents));
		    	// 	// s.check();
		    		
			    // }
			    // else
			    // {
			    // 	cout << "UnSat" << endl;
			    // }
			    s.check();
			    s.check();
			}
		}
	}
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
	outFile << "numProcess, segLength, eps, mean, sd" << endl;
	int numIter = 2;

	for(int segLength = 5; segLength <= 15; segLength = segLength + 3)
	{
		for(int eps = 5; eps <= 25; eps = eps + 3)
		{
			// int segLength = 15;
			// int eps = 15;
			int numProcess = 2;
			int compLength = 20;
			int eventRate = 10;

			vector<float> resultTime;
			for(int  i = 0; i < numIter; i++)
			{
				string traceFileName = "trace" + to_string(numProcess) + "_" + to_string(compLength) + "_" + to_string(eventRate);
				makeSMT smt("G(a I ((F b) U (! c)))", traceFileName);
				clock_t runTime = clock();
				smt.solveSMT(segLength, eps);
				runTime = clock() - runTime;
				resultTime.push_back((float) runTime / CLOCKS_PER_SEC);
			}
			float avg = findAverage(resultTime);
			float sd = findStdDeviation(resultTime, avg);

			cout << "numProcess: " << numProcess << " segLength: " << segLength << " eps: " << eps << " mean: " << avg << " sd: " << sd << endl;
			outFile << numProcess << ", " << segLength << ", " << eps << ", " << avg << ", " << sd << endl;
		}
	}
	outFile.close();
}

int main()
{
	mainProg obj;
	obj.execute();

	return 1;
}
