import { Controller, Get, Param, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard.js';
import type { AuthedRequest } from '../auth/jwt-auth.guard.js';
import { ChatService } from './chat.service.js';

@Controller('chat')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('conversations')
  conversations(@Req() request: AuthedRequest) {
    return this.chatService.conversations(request.userId);
  }

  @Get('messages/:otherUserId')
  messages(@Req() request: AuthedRequest, @Param('otherUserId') otherUserId: string) {
    return this.chatService.history(request.userId, otherUserId);
  }
}
