use AdventureWorks2022;
go

create schema audit;
go

create table audit.discountlog (
    logid int identity(1,1) primary key,
    salesorderid int,
    productid int,
    discountpercent decimal(5,2),
    attemptdate datetime
);
go

create table audit.pricechangelog (
    logid int identity(1,1) primary key,
    productid int,
    oldprice money,
    newprice money,
    changedate datetime
);
go

create table audit.employeedeletelog (
    logid int identity(1,1) primary key,
    employeeid int,
    nationalidnumber nvarchar(15),
    jobtitle nvarchar(50),
    deletedate datetime
);
go

create table audit.databasechangelog (
    logid int identity(1,1) primary key,
    eventtype nvarchar(100),
    objectname nvarchar(100),
    eventdate datetime
);
go

select * from audit.discountlog
select * from audit.pricechangelog
select * from audit.employeedeletelog
select * from audit.databasechangelog

create trigger trg_productpriceaudit
on production.product
after update
as
begin

insert into audit.pricechangelog
(productid, oldprice, newprice, changedate)

select
d.productid,
d.listprice,
i.listprice,
getdate()

from deleted d
join inserted i
on d.productid = i.productid

where d.listprice <> i.listprice

end
go

update production.product
set listprice = listprice + 1
where productid = 1

select * from audit.pricechangelog

create trigger trg_employeedeleteaudit
on humanresources.employee
after delete
as
begin

insert into audit.employeedeletelog
(employeeid, nationalidnumber, jobtitle, deletedate)

select
d.businessentityid,
d.nationalidnumber,
d.jobtitle,
getdate()

from deleted d

end
go

insert into audit.employeedeletelog
(employeeid, nationalidnumber, jobtitle, deletedate)

select
businessentityid,
nationalidnumber,
jobtitle,
getdate()

from humanresources.employee
where businessentityid = 2

select * from audit.employeedeletelog

create trigger trg_discountvalidation
on sales.salesorderdetail
after insert, update
as
begin

if exists (
    select *
    from inserted
    where unitpricediscount > 0.30
)

begin

insert into audit.discountlog
(salesorderid, productid, discountpercent, attemptdate)

select
salesorderid,
productid,
unitpricediscount,
getdate()
from inserted
where unitpricediscount > 0.30

raiserror('discount cannot exceed 30 percent',16,1)
rollback transaction

end

end
go

update sales.salesorderdetail
set unitpricediscount = 0.50
where salesorderid = 43659

select * from audit.discountlog

create trigger trg_purchasedatevalidation
on purchasing.purchaseorderheader
instead of insert
as
begin

if exists (
    select *
    from inserted
    where orderdate > getdate()
)
begin
    raiserror('order date cannot be later than today',16,1)
end
else
begin
    insert into purchasing.purchaseorderheader
    (
        revisionnumber,
        status,
        employeeid,
        vendorid,
        shipmethodid,
        orderdate,
        subtotal,
        taxamt,
        freight,
        modifieddate
    )
    select
        revisionnumber,
        status,
        employeeid,
        vendorid,
        shipmethodid,
        orderdate,
        subtotal,
        taxamt,
        freight,
        modifieddate
    from inserted
end

end
go

insert into purchasing.purchaseorderheader
(
    revisionnumber,
    status,
    employeeid,
    vendorid,
    shipmethodid,
    orderdate,
    subtotal,
    taxamt,
    freight,
    modifieddate
)
values
(
    1,
    1,
    250,
    1492,
    5,
    '2099-12-31',
    100,
    10,
    5,
    getdate()
)

create trigger trg_databasemonitoring
on database
for drop_table, alter_table
as
begin

insert into audit.databasechangelog
(eventtype, objectname, eventdate)

select
eventdata().value('(/EVENT_INSTANCE/EventType)[1]', 'nvarchar(100)'),
eventdata().value('(/EVENT_INSTANCE/ObjectName)[1]', 'nvarchar(100)'),
getdate()

end
go

create table test_trigger_table
(
id int
)

drop table test_trigger_table

select * from audit.databasechangelog