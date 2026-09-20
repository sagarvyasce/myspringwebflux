package com.spring.app.myspringwebflux;

public record Order(
		int id,
		String customerName,
		String status,
		double totalAmount) {
}