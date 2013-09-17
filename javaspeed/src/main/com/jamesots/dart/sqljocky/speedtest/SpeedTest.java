package com.jamesots.dart.sqljocky.speedtest;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.Statement;

public class SpeedTest {
    Connection cnx;

    void run() throws Exception {
        Class.forName("com.mysql.jdbc.Driver");

        cnx = DriverManager.getConnection("jdbc:mysql://localhost:3306/test",
                "test", "test");

        dropTables();
        createTables();
        insertSimpleData();
        insertPreparedData();
    }

    private void insertPreparedData() throws Exception {
        long now = System.currentTimeMillis();
        final PreparedStatement stmt = cnx.prepareStatement("insert into people (name, age) values (?, ?)");
        for (int i = 0; i < 200; i++) {
            stmt.setString(1, "person" + i);
            stmt.setInt(2, i);
            stmt.execute();
        }
        long elapsed = System.currentTimeMillis() - now;
        System.out.println("Prepared insertions: " + (elapsed / 1000.0) + "s");
    }

    private void insertSimpleData() throws Exception {
        long now = System.currentTimeMillis();
        final Statement stmt = cnx.createStatement();
        for (int i = 0; i < 200; i++) {
            stmt.execute("insert into people (name, age) values ('person" + i + "', " + i + ")");
        }
        long elapsed = System.currentTimeMillis() - now;
        System.out.println("Simple insertions: " + (elapsed / 1000.0) + "s");
    }

    private void createTables() throws Exception {
        cnx.createStatement().execute("create table people (id integer not null auto_increment, " +
                "name varchar(255), " +
                "age integer, " +
                "primary key (id))");

        cnx.createStatement().execute("create table pets (id integer not null auto_increment, " +
                "name varchar(255), " +
                "species varchar(255), " +
                "owner_id integer, " +
                "primary key (id), " +
                "foreign key (owner_id) references people (id))");
    }

    private void dropTables() throws Exception {
        try {
            cnx.createStatement().execute("drop table pets");
        } catch (Exception e) {

        }
        try {
            cnx.createStatement().execute("drop table people");
        } catch (Exception e) {

        }
    }

    public static void main(String[] args) {
        try {
            SpeedTest test = new SpeedTest();
            test.run();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
