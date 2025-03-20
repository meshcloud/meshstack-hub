import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { Router, RouterModule } from '@angular/router';

@Component({
  selector: 'app-card',
  imports: [RouterModule, CommonModule],
  templateUrl: './card.component.html',
  styleUrl: './card.component.scss',
  standalone: true
})
export class CardComponent {
  @Input() imageUrl: string| null = null;

  @Input() platformType!: string;

  @Input() title!: string;

  @Input() description!: string;

  @Input() date: string | null = null;

  @Input() detailsRoute!: string;

  constructor(private router: Router) {}

  public goToDetails() {
    // TODO this.router.navigate([this.detailsRoute]);
  }
}

