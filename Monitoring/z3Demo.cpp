#include"z3++.h"
#include<iostream>
#include<math.h>
#include <time.h>

using namespace std;
using namespace z3;

int main()
{
    clock_t runTime = clock();
	context c;
	solver s(c);

	expr_vector eventList(c);

	int numEventsProc1 = 3;
	int numEventsProc2 = 3;
	int totNumEvents = numEventsProc1 + numEventsProc2;

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

    //the consistent cuts should be consistent with the happen-before relation
    int hbSet[5][2] = {{1, 2}, {2, 3}, {4, 5}, {5, 6}, {2, 5}};

    for(int i = 0; i < 5; i++)
    {
        string str = "b1" + std::to_string(i);
        b1.push_back(c.bv_const(str.c_str(), totNumEvents));
        str = "b2" + std::to_string(i);
        b2.push_back(c.bv_const(str.c_str(), totNumEvents));
        int p0 = (int)pow(2, hbSet[i][0] - 1);
        int p1 = (int)pow(2, hbSet[i][1] - 1);

        s.add(b1[i] == p1);
        s.add(b2[i] == p0);
        s.add(forall(x, implies(bv2int(rho(x) & b1[i], false) != 0, bv2int(rho(x) & b2[i], false) != 0)));
    }

    // local time of occurrence of each event
    int time[6] = {1, 4, 7, 2, 5, 8};
    int epsilon = 2;

    //possible global time of occurence of each event
    func_decl event_time = z3::function("event_time", c.int_sort(), c.int_sort());

    for(int i = 0; i < 6; i++)
    {
        expr_vector time_range(c);
        
        for(int j = max(0, time[i] - epsilon + 1); j < time[i] + epsilon - 1; j++)
            time_range.push_back(event_time(i) == j);

        s.add(mk_or(time_range));
    }

    func_decl time_seq = z3::function("time_seq", c.int_sort(), c.int_sort());
    expr y = c.int_const("y");
    s.add(0 <= y && y <= totNumEvents);

    for(int i = 0; i < totNumEvents; i++)
    {
        expr_vector time_seq_domain(c);

        for(int j = 0; j < 6; j++)
            time_seq_domain.push_back(time_seq(i) == event_time(j));

        s.add(mk_or(time_seq_domain));
    }

    for(int i = 0; i < totNumEvents; i++)
    {
        int p = (int)pow(2, i);

        s.add(exists(y, implies(bv2int(rho(y), false) - bv2int(rho(y+1), false) == p, 
            time_seq(y) == event_time(i))));
    }

    // expr z = c.int_const("z");
    // s.add(0 <= z && z <= totNumEvents - 1);
    // s.add(forall(z, time_seq(z) <= time_seq(z + 1)));

    expr_vector val1(c);

    for(int i = 0; i < pow(2, totNumEvents); i++)
    {
    	string str = "valp" + to_string(i);
    	val1.push_back(c.int_const(str.c_str()));
    	if(i == 63)
    		s.add(val1[i] == 0);
    	else
    		s.add(val1[i] == 1);
    }

    expr v1 = c.int_const("v1");
    s.add(1 <= v1 && v1 <= totNumEvents);
    // s.add(forall(v1, val1[bv2int(rho(v1), totNumEvents)] == 1));
    s.add(exists(v1, val1[bv2int(rho(v1), totNumEvents)] == 1));

    if(s.check() == sat)
    {
    	model m = s.get_model();
    	cout << m << endl;
    }
    else
    	cout << "UnSat" << endl;

    runTime = clock() - runTime;
    float resultTime = (float) runTime / CLOCKS_PER_SEC;
    cout << "\n\nTime Taken: " << resultTime << endl;
}