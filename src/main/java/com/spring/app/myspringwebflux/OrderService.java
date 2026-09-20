package com.spring.app.myspringwebflux;

import java.util.List;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@Service
public class OrderService {

	private final Map<Integer, Order> orders;

	public OrderService() {
		var seededOrders = List.of(
				new Order(1001,
						"Ava One", "PAID", 324.00),
				new Order(1002,
						"Ben Two", "CONFIRMED", 399.60),
				new Order(1003,
						"Cara Three", "FULFILLED", 248.40));
		this.orders = seededOrders.stream().collect(Collectors.toMap(Order::id, Function.identity(), (first, second) -> second,
				HashMap::new));
	}

	public Mono<Order> fetchOrderByOrderId(int orderId) {
		return Mono.justOrEmpty(orders.get(orderId));
	}

	public Flux<Order> fetchAllOrders() {
		return Flux.fromIterable(orders.values());
	}

	public Mono<Order> addOrder(Order order) {
		orders.put(order.id(), order);
		return Mono.just(order);
	}

	public Mono<Boolean> deleteOrderById(int orderId) {
		return Mono.just(orders.remove(orderId) != null);
	}
}