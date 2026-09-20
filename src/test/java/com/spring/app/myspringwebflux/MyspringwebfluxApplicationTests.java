package com.spring.app.myspringwebflux;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.cloud.gateway.route.RouteLocator;
import org.springframework.test.web.reactive.server.WebTestClient;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class MyspringwebfluxApplicationTests {

	@Autowired
	private RouteLocator routeLocator;

	@LocalServerPort
	private int port;

	@Test
	void contextLoads() {
	}

	@Test
	void configuresThePlaceholderApiRoute() {
		var route = routeLocator.getRoutes()
				.filter(candidate -> candidate.getId().equals("local-api-placeholder"))
				.next()
				.block();

		assertThat(route).isNotNull();
		assertThat(route.getMetadata())
				.containsEntry("connect-timeout", 2000)
				.containsEntry("response-timeout", 5000);
		assertThat(route.getFilters()).hasSize(3);
	}

	@Test
	void leavesGatewayRootPublicAndAllowsUnauthenticatedApiRequests() {
		var webTestClient = WebTestClient.bindToServer()
				.baseUrl("http://localhost:" + port)
				.build();

		webTestClient.get().uri("/").exchange()
				.expectStatus().isOk()
				.expectBody(String.class).isEqualTo("myspringwebflux is running");

		webTestClient.get().uri("/api/orders").exchange()
				.expectStatus().is5xxServerError();
	}

}
