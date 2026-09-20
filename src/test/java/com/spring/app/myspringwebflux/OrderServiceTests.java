package com.spring.app.myspringwebflux;

import org.junit.jupiter.api.Test;

import reactor.test.StepVerifier;

class OrderServiceTests {

	private final OrderService orderService = new OrderService();

	@Test
	void fetchesOrderByOrderId() {
		var orderId = 1001;

		StepVerifier.create(orderService.fetchOrderByOrderId(orderId))
				.assertNext(order -> {
					assert order.id() == orderId;
					assert order.customerName().equals("Ava One");
					assert order.status().equals("PAID");
					assert order.totalAmount() == 324.00;
				})
				.verifyComplete();
	}

	@Test
	void returnsEmptyMonoForUnknownOrderId() {
		var unknownOrderId = 9999;

		StepVerifier.create(orderService.fetchOrderByOrderId(unknownOrderId))
				.verifyComplete();
	}

	@Test
	void fetchesAllOrders() {
		StepVerifier.create(orderService.fetchAllOrders().count())
				.expectNext(3L)
				.verifyComplete();
	}

	@Test
	void addsAndDeletesOrder() {
		var order = new Order(1004, "Dina Four", "PENDING", 199.99);

		StepVerifier.create(orderService.addOrder(order))
				.expectNext(order)
				.verifyComplete();

		StepVerifier.create(orderService.fetchOrderByOrderId(1004))
				.expectNext(order)
				.verifyComplete();

		StepVerifier.create(orderService.deleteOrderById(1004))
				.expectNext(true)
				.verifyComplete();

		StepVerifier.create(orderService.fetchOrderByOrderId(1004))
				.verifyComplete();
	}
}