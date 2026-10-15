class Person
{
  U8 first    [32];
  U8 last     [32];
  U8 address1 [64];
  U8 address2 [64];
  U8 city     [32];
  U8 state_zip[32];
};

U0 OffsetDemo1()
{
  Person *p=MAlloc(sizeof(Person));
  StrCpy(p->first,    "Lost");
  StrCpy(p->last,     "Soul");
  StrCpy(p->address1, "666 Brimstone Way");
  StrCpy(p->address2, "");
  StrCpy(p->city,     "Pandemonium");
  StrCpy(p->state_zip,"Circle 9");
}

U(&OffsetDemo1,34);
PressAKey;

/*

x86 has signed 8-bit  displacements
    and signed 32-bit displacements.

This example uses 8-bit negative displacements.

*/

class Person
{ $$=-128;
U8 first    [32];
U8 last     [32];
U8 address1 [64];
U8 address2 [64];
U8 city     [32];
U8 state_zip[32];
};

U0 OffsetDemo2()
{
  Person *p=MAlloc(sizeof(Person))(I64)+128;
  StrCpy(p->first,    "Lost");
  StrCpy(p->last,     "Soul");
  StrCpy(p->address1, "666 Brimstone Way");
  StrCpy(p->address2, "");
  StrCpy(p->city,     "Pandemonium");
  StrCpy(p->state_zip,"Circle 9");
}

U(&OffsetDemo2,34);
PressAKey;
